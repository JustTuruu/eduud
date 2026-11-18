package mn.eduud.admin;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import mn.eduud.auctions.AuctionRounds;
import mn.eduud.auctions.AuctionsService;
import mn.eduud.categories.CategoriesService;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthAnnotations.Roles;
import mn.eduud.common.auth.AuthUser;
import mn.eduud.realtime.RealtimeGateway;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Roles("admin")
@RestController
@RequestMapping("/admin")
public class AdminController {
  private static final List<String> AUCTION_STATUSES =
      List.of("draft", "scheduled", "live", "ended", "settled", "cancelled");

  /** auctions-ийн бүх багана + lastBidder {id,name} + order (Prisma include). */
  private static final String ADMIN_AUCTION_SELECT =
      "SELECT a.id, a.title, a.description, a.images, a.start_price, a.increment, a.soft_close_sec, a.extend_sec,"
          + " a.hard_close_at, a.starts_at, a.ends_at, a.current_price, a.bid_count, a.last_bidder_id, a.status,"
          + " a.created_by AS created_by_id, a.created_at, a.updated_at, a.rounds, a.category_id, c.name AS category_name,"
          + " CASE WHEN lb.id IS NULL THEN NULL ELSE json_build_object('id', lb.id, 'name', lb.name) END AS last_bidder,"
          + " CASE WHEN o.id IS NULL THEN NULL ELSE json_build_object('id', o.id, 'auctionId', o.auction_id,"
          + "   'winnerId', o.winner_id, 'finalPrice', o.final_price,"
          + "   'payDeadline', to_char(o.pay_deadline, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'), 'status', o.status,"
          + "   'deliveryInfo', o.delivery_info,"
          + "   'createdAt', to_char(o.created_at, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"'),"
          + "   'updatedAt', to_char(o.updated_at, 'YYYY-MM-DD\"T\"HH24:MI:SS.MS\"Z\"')) END AS \"order\""
          + " FROM auctions a LEFT JOIN users lb ON lb.id = a.last_bidder_id LEFT JOIN orders o ON o.auction_id = a.id"
          + " LEFT JOIN categories c ON c.id = a.category_id";

  private final JdbcClient db;
  private final Rows rows;
  private final TransactionTemplate tx;
  private final AuctionsService auctions;
  private final RealtimeGateway realtime;
  private final CategoriesService categories;

  public AdminController(
      JdbcClient db,
      Rows rows,
      TransactionTemplate tx,
      AuctionsService auctions,
      RealtimeGateway realtime,
      CategoriesService categories) {
    this.db = db;
    this.rows = rows;
    this.tx = tx;
    this.auctions = auctions;
    this.realtime = realtime;
    this.categories = categories;
  }

  // ---------- DTOs ----------

  public record CreateAuctionDto(
      @NotNull @Size(min = 3, max = 120) String title,
      @NotNull @Size(max = 5000) String description,
      @NotNull @Size(max = 10) List<@org.hibernate.validator.constraints.URL String> images,
      @NotNull @Min(0) Integer startPrice,
      @NotNull @Min(1) @Max(1000000) Integer increment,
      @NotNull @Min(0) @Max(3600) Integer softCloseSec,
      @NotNull @Min(0) @Max(3600) Integer extendSec,
      Instant hardCloseAt,
      @NotNull Instant startsAt,
      @NotNull Instant endsAt,
      List<AuctionRounds.Round> rounds,
      String categoryId) {}

  public record UpdateAuctionDto(
      @Size(min = 3, max = 120) String title,
      @Size(max = 5000) String description,
      @Size(max = 10) List<@org.hibernate.validator.constraints.URL String> images,
      @Min(0) Integer startPrice,
      @Min(1) @Max(1000000) Integer increment,
      @Min(0) @Max(3600) Integer softCloseSec,
      @Min(0) @Max(3600) Integer extendSec,
      Instant hardCloseAt,
      Instant startsAt,
      Instant endsAt,
      List<AuctionRounds.Round> rounds,
      String categoryId) {}

  public record UpsertPackageDto(@NotNull @Min(1) Integer tokens, @NotNull @Min(100) Integer priceMnt, Boolean active, Integer sortOrder) {}

  public record UpdateContentDto(@NotNull @Size(max = 200) String title, @NotNull String body) {}

  public record AdjustTokensDto(@NotNull Integer amount, @NotNull @Size(max = 200) String note) {}

  // ---------- Auctions ----------

  @GetMapping("/auctions")
  public List<Map<String, Object>> listAuctions(@RequestParam(required = false) String status) {
    if (status != null && AUCTION_STATUSES.contains(status)) {
      return db.sql(ADMIN_AUCTION_SELECT + " WHERE a.status = CAST(? AS \"AuctionStatus\") ORDER BY a.created_at DESC LIMIT 200")
          .param(status)
          .query(rows.camel())
          .list();
    }
    return db.sql(ADMIN_AUCTION_SELECT + " ORDER BY a.created_at DESC LIMIT 200").query(rows.camel()).list();
  }

  @PostMapping("/auctions")
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> createAuction(@CurrentUser AuthUser user, @Valid @RequestBody CreateAuctionDto dto) {
    Instant startsAt = dto.startsAt();
    Instant endsAt = dto.endsAt();
    String roundsJson = null;
    if (dto.rounds() != null) {
      // Раундтай бол эхлэх/дуусах хугацаа хуваарьаас гарна
      AuctionRounds.validate(dto.rounds());
      roundsJson = AuctionRounds.toJson(dto.rounds());
      startsAt = dto.rounds().get(0).startsAt();
      endsAt = dto.rounds().get(dto.rounds().size() - 1).endsAt();
    }
    if (!endsAt.isAfter(startsAt)) {
      throw ApiException.badRequest("Дуусах хугацаа эхлэхээс хойш байх ёстой.");
    }
    String categoryId = blankToNull(dto.categoryId());
    categories.requireExists(categoryId);
    String id = Ids.uuid();
    db.sql(
            "INSERT INTO auctions (id, title, description, images, start_price, increment, soft_close_sec, extend_sec,"
                + " hard_close_at, starts_at, ends_at, current_price, status, created_by, updated_at, rounds, category_id)"
                + " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'draft', ?, now(), CAST(? AS jsonb), ?)")
        .params(
            id,
            dto.title(),
            dto.description(),
            dto.images().toArray(new String[0]),
            dto.startPrice(),
            dto.increment(),
            dto.softCloseSec(),
            dto.extendSec(),
            Rows.ts(dto.hardCloseAt()),
            Rows.ts(startsAt),
            Rows.ts(endsAt),
            dto.startPrice(),
            user.id(),
            roundsJson,
            categoryId)
        .update();
    return auctionRow(id);
  }

  @PatchMapping("/auctions/{id}")
  public Map<String, Object> updateAuction(@PathVariable UUID id, @Valid @RequestBody UpdateAuctionDto dto) {
    String status =
        db.sql("SELECT status FROM auctions WHERE id = ?")
            .param(id.toString())
            .query(String.class)
            .optional()
            .orElseThrow(() -> ApiException.notFound("Дуудлага худалдаа олдсонгүй"));
    if (!"draft".equals(status)) throw ApiException.badRequest("Зөвхөн draft auction засах боломжтой.");

    List<String> sets = new ArrayList<>();
    List<Object> params = new ArrayList<>();
    set(sets, params, "title", dto.title());
    set(sets, params, "description", dto.description());
    if (dto.images() != null) set(sets, params, "images", dto.images().toArray(new String[0]));
    set(sets, params, "start_price", dto.startPrice());
    if (dto.startPrice() != null) set(sets, params, "current_price", dto.startPrice());
    set(sets, params, "increment", dto.increment());
    set(sets, params, "soft_close_sec", dto.softCloseSec());
    set(sets, params, "extend_sec", dto.extendSec());
    set(sets, params, "hard_close_at", Rows.ts(dto.hardCloseAt()));
    if (dto.rounds() != null) {
      // Зөвхөн draft үед (дээрх guard) — хуваарь эхлэх/дуусах хугацааг тодорхойлно
      AuctionRounds.validate(dto.rounds());
      sets.add("rounds = CAST(? AS jsonb)");
      params.add(AuctionRounds.toJson(dto.rounds()));
      set(sets, params, "starts_at", Rows.ts(dto.rounds().get(0).startsAt()));
      set(sets, params, "ends_at", Rows.ts(dto.rounds().get(dto.rounds().size() - 1).endsAt()));
    } else {
      set(sets, params, "starts_at", Rows.ts(dto.startsAt()));
      set(sets, params, "ends_at", Rows.ts(dto.endsAt()));
    }
    if (dto.categoryId() != null) {
      // Хоосон string = ангилалгүй болгох
      String categoryId = blankToNull(dto.categoryId());
      categories.requireExists(categoryId);
      sets.add("category_id = ?");
      params.add(categoryId);
    }
    sets.add("updated_at = now()");
    params.add(id.toString());
    db.sql("UPDATE auctions SET " + String.join(", ", sets) + " WHERE id = ?").params(params).update();
    return auctionRow(id.toString());
  }

  private static String blankToNull(String v) {
    return v == null || v.isBlank() ? null : v;
  }

  private static void set(List<String> sets, List<Object> params, String column, Object value) {
    if (value == null) return;
    sets.add(column + " = ?");
    params.add(value);
  }

  private Map<String, Object> auctionRow(String id) {
    return db.sql(
            "SELECT a.id, a.title, a.description, a.images, a.start_price, a.increment, a.soft_close_sec, a.extend_sec,"
                + " a.hard_close_at, a.starts_at, a.ends_at, a.current_price, a.bid_count, a.last_bidder_id, a.status,"
                + " a.created_by AS created_by_id, a.created_at, a.updated_at, a.rounds, a.category_id,"
                + " c.name AS category_name FROM auctions a LEFT JOIN categories c ON c.id = a.category_id"
                + " WHERE a.id = ?")
        .param(id)
        .query(rows.camel())
        .single();
  }

  @PostMapping("/auctions/{id}/publish")
  public Map<String, Object> publish(@PathVariable UUID id) {
    return auctions.publish(id.toString());
  }

  @PostMapping("/auctions/{id}/cancel")
  public Map<String, Object> cancel(@PathVariable UUID id) {
    return auctions.cancel(id.toString());
  }

  // ---------- Users ----------

  @GetMapping("/users")
  public List<Map<String, Object>> users(@RequestParam(required = false) String q) {
    String sql =
        "SELECT u.id, u.phone, u.name, u.role, u.status, u.created_at,"
            + " CASE WHEN w.user_id IS NULL THEN NULL ELSE json_build_object('balance', w.balance) END AS wallet"
            + " FROM users u LEFT JOIN wallets w ON w.user_id = u.id";
    if (q != null && !q.isEmpty()) {
      return db.sql(sql + " WHERE u.phone LIKE ? OR u.name ILIKE ? ORDER BY u.created_at DESC LIMIT 100")
          .params("%" + q + "%", "%" + q + "%")
          .query(rows.camel())
          .list();
    }
    return db.sql(sql + " ORDER BY u.created_at DESC LIMIT 100").query(rows.camel()).list();
  }

  @PostMapping("/users/{id}/ban")
  public Map<String, Object> ban(@PathVariable UUID id) {
    return setStatus(id, "banned");
  }

  @PostMapping("/users/{id}/unban")
  public Map<String, Object> unban(@PathVariable UUID id) {
    return setStatus(id, "active");
  }

  private Map<String, Object> setStatus(UUID id, String status) {
    int n =
        db.sql("UPDATE users SET status = CAST(? AS \"UserStatus\"), updated_at = now() WHERE id = ?")
            .params(status, id.toString())
            .update();
    if (n == 0) throw ApiException.notFound("Хэрэглэгч олдсонгүй");
    return Map.of("ok", true);
  }

  /** Гараар token нэмэх/хасах (ledger-т admin_adjust гэж бичигдэнэ). */
  @PostMapping("/users/{id}/adjust-tokens")
  public Map<String, Object> adjustTokens(@PathVariable UUID id, @Valid @RequestBody AdjustTokensDto dto) {
    if (dto.amount() == 0) throw ApiException.badRequest("amount 0 байж болохгүй");
    String userId = id.toString();
    Integer newBalance =
        tx.execute(
            s -> {
              Integer balance =
                  db.sql(
                          "UPDATE wallets SET balance = balance + ?, updated_at = now()"
                              + " WHERE user_id = ? AND balance + ? >= 0 RETURNING balance")
                      .params(dto.amount(), userId, dto.amount())
                      .query(Integer.class)
                      .optional()
                      .orElseThrow(() -> ApiException.badRequest("Үлдэгдэл хүрэлцэхгүй эсвэл данс алга."));
              db.sql(
                      "INSERT INTO token_transactions (id, user_id, amount, type, note)"
                          + " VALUES (?, ?, ?, 'admin_adjust', ?)")
                  .params(Ids.uuid(), userId, dto.amount(), dto.note())
                  .update();
              return balance;
            });
    realtime.emitToUser(userId, "wallet_updated", Map.of("balance", newBalance));
    return Map.of("ok", true, "balance", newBalance);
  }

  // ---------- Payments / Orders ----------

  @GetMapping("/payments")
  public List<Map<String, Object>> payments() {
    return db.sql(
            "SELECT p.id, p.user_id, p.kind, p.package_id, p.order_id, p.wire_invoice_id, p.amount_mnt, p.status,"
                + " p.raw_webhook, p.paid_at, p.created_at,"
                + " json_build_object('id', u.id, 'phone', u.phone, 'name', u.name) AS user,"
                + " CASE WHEN tp.id IS NULL THEN NULL ELSE json_build_object('id', tp.id, 'tokens', tp.tokens,"
                + "   'priceMnt', tp.price_mnt, 'active', tp.active, 'sortOrder', tp.sort_order) END AS package"
                + " FROM payments p JOIN users u ON u.id = p.user_id LEFT JOIN token_packages tp ON tp.id = p.package_id"
                + " ORDER BY p.created_at DESC LIMIT 200")
        .query(rows.camel())
        .list();
  }

  @GetMapping("/orders")
  public List<Map<String, Object>> orders() {
    return db.sql(
            "SELECT o.id, o.auction_id, o.winner_id, o.final_price, o.pay_deadline, o.status, o.delivery_info,"
                + " o.created_at, o.updated_at,"
                + " json_build_object('id', u.id, 'phone', u.phone, 'name', u.name) AS winner,"
                + " json_build_object('id', a.id, 'title', a.title) AS auction"
                + " FROM orders o JOIN users u ON u.id = o.winner_id JOIN auctions a ON a.id = o.auction_id"
                + " ORDER BY o.created_at DESC LIMIT 200")
        .query(rows.camel())
        .list();
  }

  @PatchMapping("/orders/{id}/delivery")
  public Map<String, Object> updateDelivery(@PathVariable UUID id, @RequestBody Map<String, Object> body) {
    return db.sql(
            "UPDATE orders SET delivery_info = CAST(? AS jsonb), updated_at = now() WHERE id = ?"
                + " RETURNING id, auction_id, winner_id, final_price, pay_deadline, status, delivery_info,"
                + " created_at, updated_at")
        .params(rows.toJson(body), id.toString())
        .query(rows.camel())
        .optional()
        .orElseThrow(() -> ApiException.notFound("Захиалга олдсонгүй"));
  }

  // ---------- Packages ----------

  @GetMapping("/packages")
  public List<Map<String, Object>> packages() {
    return db.sql("SELECT id, tokens, price_mnt, active, sort_order FROM token_packages ORDER BY sort_order ASC")
        .query(rows.camel())
        .list();
  }

  @PostMapping("/packages")
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> createPackage(@Valid @RequestBody UpsertPackageDto dto) {
    return db.sql(
            "INSERT INTO token_packages (id, tokens, price_mnt, active, sort_order) VALUES (?, ?, ?, ?, ?)"
                + " RETURNING id, tokens, price_mnt, active, sort_order")
        .params(
            Ids.uuid(),
            dto.tokens(),
            dto.priceMnt(),
            dto.active() == null || dto.active(),
            dto.sortOrder() == null ? 0 : dto.sortOrder())
        .query(rows.camel())
        .single();
  }

  @PatchMapping("/packages/{id}")
  public Map<String, Object> updatePackage(@PathVariable UUID id, @Valid @RequestBody UpsertPackageDto dto) {
    return db.sql(
            "UPDATE token_packages SET tokens = ?, price_mnt = ?, active = COALESCE(?, active),"
                + " sort_order = COALESCE(?, sort_order) WHERE id = ? RETURNING id, tokens, price_mnt, active, sort_order")
        .params(dto.tokens(), dto.priceMnt(), dto.active(), dto.sortOrder(), id.toString())
        .query(rows.camel())
        .optional()
        .orElseThrow(() -> ApiException.notFound("Багц олдсонгүй"));
  }

  // ---------- Content ----------

  @PatchMapping("/content/{key}")
  public Map<String, Object> updateContent(@PathVariable String key, @Valid @RequestBody UpdateContentDto dto) {
    return db.sql(
            "INSERT INTO app_content (key, title, body, updated_at) VALUES (?, ?, ?, now())"
                + " ON CONFLICT (key) DO UPDATE SET title = EXCLUDED.title, body = EXCLUDED.body, updated_at = now()"
                + " RETURNING key, title, body, updated_at")
        .params(key, dto.title(), dto.body())
        .query(rows.camel())
        .single();
  }
}
