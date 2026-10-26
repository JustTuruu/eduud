package mn.eduud.auth;

import io.jsonwebtoken.Claims;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.JwtService;
import mn.eduud.common.auth.PasswordHasher;
import mn.eduud.config.AppProperties;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
  private final JdbcClient db;
  private final Rows rows;
  private final JwtService jwt;
  private final PasswordHasher hasher;
  private final OtpService otp;
  private final long refreshTtlSec;

  public AuthService(
      JdbcClient db, Rows rows, JwtService jwt, PasswordHasher hasher, OtpService otp, AppProperties props) {
    this.db = db;
    this.rows = rows;
    this.jwt = jwt;
    this.hasher = hasher;
    this.otp = otp;
    this.refreshTtlSec = props.jwt().refreshTtlSec();
  }

  // ---------- OTP ----------

  public Map<String, Object> requestOtp(String phone, String purpose) {
    boolean exists = findUserByPhone(phone) != null;
    if ("register".equals(purpose) && exists) throw ApiException.conflict("Энэ дугаар бүртгэлтэй байна. Нэвтэрнэ үү.");
    if ("reset".equals(purpose) && !exists) throw ApiException.badRequest("Энэ дугаар бүртгэлгүй байна.");
    String devCode = otp.request(phone, purpose);
    Map<String, Object> res = new LinkedHashMap<>();
    res.put("ok", true);
    res.put("devCode", devCode);
    return res;
  }

  /** OTP зөв бол 10 минутын ticket (JWT) буцаана. */
  public Map<String, Object> verifyOtp(String phone, String purpose, String code) {
    otp.verify(phone, purpose, code);
    return Map.of("ticket", jwt.signTicket(phone, purpose, Duration.ofMinutes(10)));
  }

  private String consumeTicket(String ticket, String purpose) {
    try {
      Claims c = jwt.verify(ticket);
      if (!"otp-ticket".equals(c.get("kind")) || !purpose.equals(c.get("purpose"))) throw new IllegalStateException();
      return String.valueOf(c.get("phone"));
    } catch (Exception e) {
      throw ApiException.unauthorized("Ticket хүчингүй. OTP-оо дахин баталгаажуулна уу.");
    }
  }

  // ---------- Register / Login ----------

  @Transactional
  public Map<String, Object> register(String ticket, String name, String password) {
    String phone = consumeTicket(ticket, "register");
    if (findUserByPhone(phone) != null) throw ApiException.conflict("Энэ дугаар бүртгэлтэй байна.");
    String id = Ids.uuid();
    db.sql("INSERT INTO users (id, phone, name, password_hash, updated_at) VALUES (?, ?, ?, ?, now())")
        .params(id, phone, name, hasher.hash(password))
        .update();
    db.sql("INSERT INTO wallets (user_id, balance, updated_at) VALUES (?, 0, now())").param(id).update();
    return issueTokens(findUserById(id));
  }

  public Map<String, Object> login(String phone, String password) {
    Map<String, Object> user = findUserByPhone(phone);
    if (user == null || !hasher.verify((String) user.get("passwordHash"), password)) {
      throw ApiException.unauthorized("Дугаар эсвэл нууц үг буруу байна.");
    }
    if ("banned".equals(user.get("status"))) throw ApiException.unauthorized("Таны эрх хаагдсан байна.");
    return issueTokens(user);
  }

  @Transactional
  public Map<String, Object> resetPassword(String ticket, String newPassword) {
    String phone = consumeTicket(ticket, "reset");
    Map<String, Object> user = findUserByPhone(phone);
    if (user == null) throw ApiException.badRequest("Хэрэглэгч олдсонгүй.");
    db.sql("UPDATE users SET password_hash = ?, updated_at = now() WHERE id = ?")
        .params(hasher.hash(newPassword), user.get("id"))
        .update();
    // Бүх төхөөрөмжөөс гаргана
    db.sql("UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = ? AND revoked_at IS NULL")
        .param(user.get("id"))
        .update();
    return Map.of("ok", true);
  }

  // ---------- Refresh rotation ----------

  private Map<String, Object> issueTokens(Map<String, Object> user) {
    String userId = (String) user.get("id");
    String accessToken = jwt.signAccess(userId, String.valueOf(user.get("role")));
    String refreshToken = Ids.randomBase64Url(48);
    db.sql("INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)")
        .params(Ids.uuid(), userId, Ids.sha256Hex(refreshToken), Rows.ts(Instant.now().plusSeconds(refreshTtlSec)))
        .update();

    Map<String, Object> u = new LinkedHashMap<>();
    u.put("id", userId);
    u.put("phone", user.get("phone"));
    u.put("name", user.get("name"));
    u.put("avatarUrl", user.get("avatarUrl"));
    u.put("role", user.get("role"));
    Map<String, Object> res = new LinkedHashMap<>();
    res.put("accessToken", accessToken);
    res.put("refreshToken", refreshToken);
    res.put("user", u);
    return res;
  }

  @Transactional
  public Map<String, Object> refresh(String refreshToken) {
    Map<String, Object> stored =
        db.sql("SELECT id, user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = ? FOR UPDATE")
            .param(Ids.sha256Hex(refreshToken))
            .query(rows.camel())
            .optional()
            .orElse(null);
    if (stored == null
        || stored.get("revokedAt") != null
        || ((Instant) stored.get("expiresAt")).isBefore(Instant.now())) {
      throw ApiException.unauthorized("Дахин нэвтэрнэ үү.");
    }
    // Rotate: хуучныг хүчингүй болгоод шинийг олгоно
    db.sql("UPDATE refresh_tokens SET revoked_at = now() WHERE id = ?").param(stored.get("id")).update();
    return issueTokens(findUserById((String) stored.get("userId")));
  }

  public Map<String, Object> logout(String refreshToken) {
    db.sql("UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = ? AND revoked_at IS NULL")
        .param(Ids.sha256Hex(refreshToken))
        .update();
    return Map.of("ok", true);
  }

  // ---------- helpers ----------

  private Map<String, Object> findUserByPhone(String phone) {
    return db.sql("SELECT id, phone, name, avatar_url, password_hash, role, status FROM users WHERE phone = ?")
        .param(phone)
        .query(rows.camel())
        .optional()
        .orElse(null);
  }

  private Map<String, Object> findUserById(String id) {
    return db.sql("SELECT id, phone, name, avatar_url, password_hash, role, status FROM users WHERE id = ?")
        .param(id)
        .query(rows.camel())
        .single();
  }
}
