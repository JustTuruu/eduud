package mn.eduud.requests;

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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** UC-05: хэрэглэгч өөрийн бараагаар дуудлага худалдаа зохион байгуулахыг хүснэ. */
@RestController
public class AuctionRequestsController {
  private static final String COLUMNS =
      "id, title, description, category, start_price, preferred_date, other_info, status::text AS status, admin_note,"
          + " created_at, updated_at";

  private final JdbcClient db;
  private final Rows rows;

  public AuctionRequestsController(JdbcClient db, Rows rows) {
    this.db = db;
    this.rows = rows;
  }

  public record CreateRequestDto(
      String title,
      String description,
      String category,
      Long startPrice,
      String preferredDate,
      String otherInfo,
      Boolean draft) {}

  /** Бүх талбар заавал биш: null бол хэвээр үлдэнэ. */
  public record UpdateRequestDto(
      String title,
      String description,
      String category,
      Long startPrice,
      String preferredDate,
      String otherInfo,
      Boolean submit) {}

  public record DecisionDto(String status, String note) {}

  @PostMapping("/auction-requests")
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> create(@CurrentUser AuthUser user, @RequestBody CreateRequestDto dto) {
    String title = AuctionRequestRules.validateTitle(dto.title());
    String description = AuctionRequestRules.validateDescription(dto.description());
    Integer startPrice = AuctionRequestRules.validateStartPrice(dto.startPrice());
    String category = AuctionRequestRules.validateOptional(dto.category(), "Ангилал");
    String preferredDate = AuctionRequestRules.validateOptional(dto.preferredDate(), "Хүссэн огноо");
    String otherInfo = AuctionRequestRules.validateOptional(dto.otherInfo(), "Бусад мэдээлэл");
    String status = AuctionRequestRules.initialStatus(dto.draft());
    return db.sql(
            "INSERT INTO auction_requests (id, user_id, title, description, category, start_price,"
                + " preferred_date, other_info, status)"
                + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, CAST(? AS \"AuctionRequestStatus\"))"
                + " RETURNING " + COLUMNS)
        .params(Ids.uuid(), user.id(), title, description, category, startPrice, preferredDate, otherInfo, status)
        .query(rows.camel())
        .single();
  }

  /** Өөрийн хүсэлтүүд, шинэ нь эхэндээ. */
  @GetMapping("/auction-requests/mine")
  public List<Map<String, Object>> mine(@CurrentUser AuthUser user) {
    return db.sql("SELECT " + COLUMNS + " FROM auction_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT 100")
        .param(user.id())
        .query(rows.camel())
        .list();
  }

  @PatchMapping("/auction-requests/{id}")
  public Map<String, Object> update(
      @CurrentUser AuthUser user, @PathVariable String id, @RequestBody UpdateRequestDto dto) {
    Map<String, Object> current = loadOwned(user, id);
    if (!AuctionRequestRules.canEdit((String) current.get("status"))) {
      throw ApiException.conflict("Энэ төлөвт хүсэлтийг засах боломжгүй.");
    }
    String title = dto.title() == null ? null : AuctionRequestRules.validateTitle(dto.title());
    String description = dto.description() == null ? null : AuctionRequestRules.validateDescription(dto.description());
    Integer startPrice = AuctionRequestRules.validateStartPrice(dto.startPrice());
    String category = AuctionRequestRules.validateOptional(dto.category(), "Ангилал");
    String preferredDate = AuctionRequestRules.validateOptional(dto.preferredDate(), "Хүссэн огноо");
    String otherInfo = AuctionRequestRules.validateOptional(dto.otherInfo(), "Бусад мэдээлэл");
    String status =
        AuctionRequestRules.statusAfterEdit((String) current.get("status"), Boolean.TRUE.equals(dto.submit()));
    return db.sql(
            "UPDATE auction_requests SET title = COALESCE(?, title), description = COALESCE(?, description),"
                + " category = COALESCE(?, category), start_price = COALESCE(?, start_price),"
                + " preferred_date = COALESCE(?, preferred_date), other_info = COALESCE(?, other_info),"
                + " status = CAST(? AS \"AuctionRequestStatus\"), updated_at = now()"
                + " WHERE id = ? AND user_id = ? AND status IN ('draft', 'info_requested')"
                + " RETURNING " + COLUMNS)
        .params(title, description, category, startPrice, preferredDate, otherInfo, status, id, user.id())
        .query(rows.camel())
        .optional()
        .orElseThrow(() -> ApiException.conflict("Энэ төлөвт хүсэлтийг засах боломжгүй."));
  }

  @PostMapping("/auction-requests/{id}/cancel")
  public Map<String, Object> cancel(@CurrentUser AuthUser user, @PathVariable String id) {
    Map<String, Object> current = loadOwned(user, id);
    if (!AuctionRequestRules.canCancel((String) current.get("status"))) {
      throw ApiException.conflict("Энэ төлөвт хүсэлтийг цуцлах боломжгүй.");
    }
    return db.sql(
            "UPDATE auction_requests SET status = 'cancelled', updated_at = now()"
                + " WHERE id = ? AND user_id = ? AND status IN ('draft', 'pending', 'info_requested')"
                + " RETURNING " + COLUMNS)
        .params(id, user.id())
        .query(rows.camel())
        .optional()
        .orElseThrow(() -> ApiException.conflict("Энэ төлөвт хүсэлтийг цуцлах боломжгүй."));
  }

  private Map<String, Object> loadOwned(AuthUser user, String id) {
    Map<String, Object> row =
        db.sql("SELECT " + COLUMNS + ", user_id FROM auction_requests WHERE id = ?")
            .param(id)
            .query(rows.camel())
            .optional()
            .orElseThrow(() -> ApiException.notFound("Хүсэлт олдсонгүй"));
    if (!user.id().equals(row.get("userId"))) {
      throw ApiException.forbidden("Энэ хүсэлт таных биш байна.");
    }
    return row;
  }

  // ---------- Админ ----------

  @Roles("admin")
  @GetMapping("/admin/auction-requests")
  public List<Map<String, Object>> adminList(@RequestParam(required = false) String status) {
    String sql =
        "SELECT r.id, r.user_id, r.title, r.description, r.category, r.start_price, r.preferred_date,"
            + " r.other_info, r.status::text AS status, r.admin_note, r.created_at, r.updated_at,"
            + " json_build_object('id', u.id, 'name', u.name, 'phone', u.phone) AS user"
            + " FROM auction_requests r JOIN users u ON u.id = r.user_id";
    if (status != null && AuctionRequestRules.ALL_STATUSES.contains(status)) {
      return db.sql(sql + " WHERE r.status = CAST(? AS \"AuctionRequestStatus\") ORDER BY r.created_at DESC LIMIT 200")
          .param(status)
          .query(rows.camel())
          .list();
    }
    return db.sql(sql + " ORDER BY r.created_at DESC LIMIT 200").query(rows.camel()).list();
  }

  @Roles("admin")
  @PostMapping("/admin/auction-requests/{id}/decision")
  public Map<String, Object> decide(@PathVariable String id, @RequestBody DecisionDto dto) {
    String note = AuctionRequestRules.validateDecision(dto.status(), dto.note());
    String current =
        db.sql("SELECT status::text FROM auction_requests WHERE id = ?")
            .param(id)
            .query(String.class)
            .optional()
            .orElseThrow(() -> ApiException.notFound("Хүсэлт олдсонгүй"));
    if (!AuctionRequestRules.canDecide(current)) {
      throw ApiException.conflict("Энэ төлөвт хүсэлтэд шийдвэр гаргах боломжгүй.");
    }
    return db.sql(
            "UPDATE auction_requests SET status = CAST(? AS \"AuctionRequestStatus\"),"
                + " admin_note = COALESCE(?, admin_note), updated_at = now()"
                + " WHERE id = ? AND status IN ('pending', 'reviewing', 'info_requested')"
                + " RETURNING " + COLUMNS)
        .params(dto.status(), note, id)
        .query(rows.camel())
        .optional()
        .orElseThrow(() -> ApiException.conflict("Энэ төлөвт хүсэлтэд шийдвэр гаргах боломжгүй."));
  }
}
