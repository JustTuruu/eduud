package mn.eduud.feedback;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthAnnotations.Roles;
import mn.eduud.common.auth.AuthUser;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/feedback")
public class FeedbackController {
  private static final String LIST_COLUMNS = "id, type, category, message, status, admin_note, created_at";
  private static final List<String> STATUSES = List.of("open", "reviewing", "resolved", "closed");

  private final JdbcClient db;
  private final Rows rows;

  public FeedbackController(JdbcClient db, Rows rows) {
    this.db = db;
    this.rows = rows;
  }

  public record CreateFeedbackDto(
      @NotNull(message = "Төрлөө сонгоно уу.")
          @Pattern(regexp = "^(bug|idea|improvement|complaint|suggestion|praise|other)$", message = "Төрлөө сонгоно уу.")
          String type,
      @NotNull(message = "Ангиллаа сонгоно уу.")
          @Pattern(
              regexp = "^(design|ux|performance|reliability|usability|content|billing|general)$",
              message = "Ангиллаа сонгоно уу.")
          String category,
      @NotNull
          @Size(min = 10, message = "Дэлгэрэнгүйг 10-аас доошгүй тэмдэгтээр бичнэ үү.")
          @Size(max = 2000, message = "Дэлгэрэнгүй 2000 тэмдэгтээс хэтэрч болохгүй.")
          String message,
      @Size(max = 30) String appVersion,
      @Size(max = 30) String platform) {}

  public record UpdateFeedbackDto(
      @NotNull @Pattern(regexp = "^(open|reviewing|resolved|closed)$") String status, @Size(max = 1000) String adminNote) {}

  /** Санал хүсэлт илгээх. */
  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> create(@CurrentUser AuthUser user, @Valid @RequestBody CreateFeedbackDto dto) {
    return db.sql(
            "INSERT INTO feedback (id, user_id, type, category, message, app_version, platform, updated_at)"
                + " VALUES (?, ?, CAST(? AS \"FeedbackType\"), CAST(? AS \"FeedbackCategory\"), ?, ?, ?, now())"
                + " RETURNING " + LIST_COLUMNS)
        .params(Ids.uuid(), user.id(), dto.type(), dto.category(), dto.message(), dto.appVersion(), dto.platform())
        .query(rows.camel())
        .single();
  }

  /** Өөрийн илгээсэн саналуудын түүх. */
  @GetMapping("/mine")
  public List<Map<String, Object>> mine(@CurrentUser AuthUser user) {
    return db.sql("SELECT " + LIST_COLUMNS + " FROM feedback WHERE user_id = ? ORDER BY created_at DESC LIMIT 50")
        .param(user.id())
        .query(rows.camel())
        .list();
  }

  // ---------- Админ ----------

  @Roles("admin")
  @GetMapping("/admin")
  public List<Map<String, Object>> adminList(@RequestParam(required = false) String status) {
    String sql =
        "SELECT f.id, f.user_id, f.type, f.category, f.message, f.app_version, f.platform, f.status, f.admin_note,"
            + " f.created_at, f.updated_at,"
            + " json_build_object('id', u.id, 'name', u.name, 'phone', u.phone) AS user"
            + " FROM feedback f JOIN users u ON u.id = f.user_id";
    if (status != null && STATUSES.contains(status)) {
      return db.sql(sql + " WHERE f.status = CAST(? AS \"FeedbackStatus\") ORDER BY f.created_at DESC LIMIT 200")
          .param(status)
          .query(rows.camel())
          .list();
    }
    return db.sql(sql + " ORDER BY f.created_at DESC LIMIT 200").query(rows.camel()).list();
  }

  @Roles("admin")
  @PatchMapping("/admin/{id}")
  public Map<String, Object> adminUpdate(@PathVariable String id, @Valid @RequestBody UpdateFeedbackDto dto) {
    return db.sql(
            "UPDATE feedback SET status = CAST(? AS \"FeedbackStatus\"), admin_note = ?, updated_at = now()"
                + " WHERE id = ? RETURNING " + LIST_COLUMNS)
        .params(dto.status(), dto.adminNote(), id)
        .query(rows.camel())
        .optional()
        .orElseThrow(() -> ApiException.notFound("Санал олдсонгүй"));
  }
}
