package mn.eduud.auth;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

/** SMS OTP — mock (dev, код логт хэвлэгдэнэ) эсвэл verify.mn (prod). */
@Service
public class OtpService {
  private static final Logger log = LoggerFactory.getLogger(OtpService.class);
  private static final int OTP_TTL_MIN = 5;
  private static final int MAX_ATTEMPTS = 5;
  private static final int MIN_RESEND_SEC = 60;
  private static final int MAX_PER_DAY = 5;

  private final JdbcClient db;
  private final Rows rows;
  private final AppProperties.Otp cfg;
  private final String secret;
  private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

  public OtpService(JdbcClient db, Rows rows, AppProperties props) {
    this.db = db;
    this.rows = rows;
    this.cfg = props.otp();
    this.secret = props.jwt().accessSecret();
  }

  public boolean isMock() {
    return cfg.isMock();
  }

  private String hash(String code) {
    return Ids.sha256Hex(code + ":" + secret);
  }

  /** @return mock горимд кодыг өөрийг нь, эсрэг тохиолдолд null. */
  public String request(String phone, String purpose) {
    Instant dayAgo = Instant.now().minus(Duration.ofHours(24));
    List<Map<String, Object>> recent =
        db.sql(
                "SELECT created_at FROM otp_codes WHERE phone = ? AND purpose = CAST(? AS \"OtpPurpose\")"
                    + " AND created_at >= ? ORDER BY created_at DESC")
            .params(phone, purpose, Rows.ts(dayAgo))
            .query(rows.camel())
            .list();
    if (recent.size() >= MAX_PER_DAY) {
      throw ApiException.badRequest("Өдрийн OTP хязгаарт хүрсэн. Маргааш дахин оролдоно уу.");
    }
    if (!recent.isEmpty()) {
      Instant last = (Instant) recent.get(0).get("createdAt");
      if (Duration.between(last, Instant.now()).getSeconds() < MIN_RESEND_SEC) {
        throw ApiException.badRequest("Түр хүлээгээд дахин код авна уу.");
      }
    }

    String code = String.valueOf(Ids.randomInt(100000, 1000000));
    db.sql(
            "INSERT INTO otp_codes (id, phone, code_hash, purpose, expires_at)"
                + " VALUES (?, ?, ?, CAST(? AS \"OtpPurpose\"), ?)")
        .params(Ids.uuid(), phone, hash(code), purpose, Rows.ts(Instant.now().plusSeconds(OTP_TTL_MIN * 60L)))
        .update();
    send(phone, code);
    return cfg.isMock() ? code : null;
  }

  /** Кодыг шалгаад амжилттай бол used гэж тэмдэглэнэ. */
  public void verify(String phone, String purpose, String code) {
    var otp =
        db.sql(
                "SELECT id, code_hash, attempts FROM otp_codes WHERE phone = ? AND purpose = CAST(? AS \"OtpPurpose\")"
                    + " AND used_at IS NULL AND expires_at >= now() ORDER BY created_at DESC LIMIT 1")
            .params(phone, purpose)
            .query(rows.camel())
            .optional()
            .orElseThrow(() -> ApiException.badRequest("Код хүчингүй эсвэл хугацаа дууссан."));
    if (((Number) otp.get("attempts")).intValue() >= MAX_ATTEMPTS) {
      throw ApiException.badRequest("Хэт олон буруу оролдлого. Шинэ код авна уу.");
    }
    if (!hash(code).equals(otp.get("codeHash"))) {
      db.sql("UPDATE otp_codes SET attempts = attempts + 1 WHERE id = ?").param(otp.get("id")).update();
      throw ApiException.badRequest("Код буруу байна.");
    }
    db.sql("UPDATE otp_codes SET used_at = now() WHERE id = ?").param(otp.get("id")).update();
  }

  private void send(String phone, String code) {
    if (cfg.isMock()) {
      log.warn("[MOCK OTP] {} -> {}", phone, code);
      return;
    }
    try {
      String body =
          "{\"phone\":\"" + phone + "\",\"message\":\"E-Duud баталгаажуулах код: " + code + "\"}";
      HttpResponse<String> res =
          http.send(
              HttpRequest.newBuilder(URI.create(cfg.verifymnApiUrl() + "/api/v1/sms/send"))
                  .header("Content-Type", "application/json")
                  .header("Authorization", "Bearer " + cfg.verifymnApiKey())
                  .POST(HttpRequest.BodyPublishers.ofString(body))
                  .build(),
              HttpResponse.BodyHandlers.ofString());
      if (res.statusCode() >= 300) {
        throw new IllegalStateException("verify.mn SMS илгээхэд алдаа: " + res.statusCode() + " " + res.body());
      }
    } catch (Exception e) {
      throw new IllegalStateException(e.getMessage(), e);
    }
  }
}
