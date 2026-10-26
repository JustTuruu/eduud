package mn.eduud.users;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.LinkedHashMap;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthUser;
import mn.eduud.common.auth.PasswordHasher;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/me")
public class UsersController {
  private final JdbcClient db;
  private final Rows rows;
  private final PasswordHasher hasher;

  public UsersController(JdbcClient db, Rows rows, PasswordHasher hasher) {
    this.db = db;
    this.rows = rows;
    this.hasher = hasher;
  }

  /**
   * avatarUrl хоёр хэлбэрийг зөвшөөрнө:
   * `https://...` (R2-д байршуулсан зураг) эсвэл `preset:<id>` (апп доторх бэлэн аватар).
   */
  public record UpdateMeDto(
      @Size(min = 2, max = 30) String name,
      @Pattern(regexp = "^(https?://\\S{3,500}|preset:[a-z0-9-]{1,32})$", message = "Аватарын утга буруу байна.")
          String avatarUrl) {}

  public record ChangePasswordDto(
      @NotNull String currentPassword,
      @NotNull @Size(min = 8, max = 72, message = "Нууц үг хамгийн багадаа 8 тэмдэгт") String newPassword) {}

  @GetMapping
  public Map<String, Object> me(@CurrentUser AuthUser user) {
    Map<String, Object> u =
        db.sql(
                "SELECT u.id, u.phone, u.name, u.avatar_url, u.role, COALESCE(w.balance, 0) AS balance"
                    + " FROM users u LEFT JOIN wallets w ON w.user_id = u.id WHERE u.id = ?")
            .param(user.id())
            .query(rows.camel())
            .optional()
            .orElseThrow(() -> ApiException.notFound("Хэрэглэгч олдсонгүй"));
    return u;
  }

  @PatchMapping
  public Map<String, Object> update(@CurrentUser AuthUser user, @Valid @RequestBody UpdateMeDto dto) {
    // Prisma: undefined талбарыг өөрчлөхгүй
    Map<String, Object> u =
        db.sql(
                "UPDATE users SET name = COALESCE(?, name), avatar_url = COALESCE(?, avatar_url), updated_at = now()"
                    + " WHERE id = ? RETURNING id, name, avatar_url")
            .params(dto.name(), dto.avatarUrl(), user.id())
            .query(rows.camel())
            .single();
    return new LinkedHashMap<>(u);
  }

  @PostMapping("/password")
  public Map<String, Object> changePassword(@CurrentUser AuthUser user, @Valid @RequestBody ChangePasswordDto dto) {
    String hash =
        db.sql("SELECT password_hash FROM users WHERE id = ?").param(user.id()).query(String.class).single();
    if (!hasher.verify(hash, dto.currentPassword())) throw ApiException.unauthorized("Одоогийн нууц үг буруу байна.");
    db.sql("UPDATE users SET password_hash = ?, updated_at = now() WHERE id = ?")
        .params(hasher.hash(dto.newPassword()), user.id())
        .update();
    return Map.of("ok", true);
  }
}
