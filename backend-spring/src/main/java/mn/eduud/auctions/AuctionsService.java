package mn.eduud.auctions;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.config.AppProperties;
import mn.eduud.realtime.RealtimeGateway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class AuctionsService {
  private static final Logger log = LoggerFactory.getLogger(AuctionsService.class);

  /** Prisma-ийн `include: { lastBidder: { select: { id, name, avatarUrl } } }`-тэй адил. */
  static final String LAST_BIDDER_JSON =
      "CASE WHEN lb.id IS NULL THEN NULL ELSE json_build_object('id', lb.id, 'name', lb.name, 'avatarUrl', lb.avatar_url) END";

  /** auctions хүснэгтийн бүх багана (Prisma-ийн field нэрээр). */
  static final String AUCTION_COLUMNS =
      "a.id, a.title, a.description, a.images, a.start_price, a.increment, a.soft_close_sec, a.extend_sec,"
          + " a.hard_close_at, a.starts_at, a.ends_at, a.current_price, a.bid_count, a.last_bidder_id, a.status,"
          + " a.created_by AS created_by_id, a.created_at, a.updated_at";

  private final JdbcClient db;
  private final Rows rows;
  private final TransactionTemplate tx;
  private final RealtimeGateway realtime;
  private final int payDeadlineHours;

  public AuctionsService(
      JdbcClient db, Rows rows, TransactionTemplate tx, RealtimeGateway realtime, AppProperties props) {
    this.db = db;
    this.rows = rows;
    this.tx = tx;
    this.realtime = realtime;
    this.payDeadlineHours = props.orders().payDeadlineHours();
  }

  // ---------- Public queries ----------

  public List<Map<String, Object>> list(String status) {
    String where;
    String order;
    if ("ended".equals(status)) {
      where = "a.status IN ('ended', 'settled')";
      order = "a.ends_at DESC";
    } else if (status != null && List.of("live", "scheduled", "draft", "settled", "cancelled").contains(status)) {
      where = "a.status = CAST(:status AS \"AuctionStatus\")";
      order = "a.ends_at ASC";
    } else {
      where = "a.status IN ('live', 'scheduled')";
      order = "a.ends_at ASC";
    }
    var q =
        db.sql(
            "SELECT a.id, a.title, a.images, a.current_price, a.bid_count, a.starts_at, a.ends_at, a.status, "
                + LAST_BIDDER_JSON
                + " AS last_bidder FROM auctions a LEFT JOIN users lb ON lb.id = a.last_bidder_id WHERE "
                + where
                + " ORDER BY "
                + order
                + " LIMIT 100");
    if (where.contains(":status")) q = q.param("status", status);
    return q.query(rows.camel()).list();
  }

  public Map<String, Object> detail(String id) {
    Map<String, Object> auction =
        db.sql(
                "SELECT "
                    + AUCTION_COLUMNS
                    + ", "
                    + LAST_BIDDER_JSON
                    + " AS last_bidder FROM auctions a LEFT JOIN users lb ON lb.id = a.last_bidder_id"
                    + " WHERE a.id = ? AND a.status <> 'draft'")
            .param(id)
            .query(rows.camel())
            .optional()
            .orElseThrow(() -> ApiException.notFound("Дуудлага худалдаа олдсонгүй"));
    List<Map<String, Object>> bids =
        db.sql(
                "SELECT b.id, b.price, b.created_at,"
                    + " json_build_object('id', u.id, 'name', u.name, 'avatarUrl', u.avatar_url) AS user"
                    + " FROM bids b JOIN users u ON u.id = b.user_id WHERE b.auction_id = ?"
                    + " ORDER BY b.created_at DESC, b.price DESC LIMIT 20")
            .param(id)
            .query(rows.camel())
            .list();
    Map<String, Object> res = new LinkedHashMap<>(auction);
    res.put("bids", bids);
    res.put("serverTime", System.currentTimeMillis());
    return res;
  }

  // ---------- Lifecycle (админ) ----------

  /** Админ draft auction-ыг нийтэлнэ: scheduled эсвэл шууд live. */
  public Map<String, Object> publish(String auctionId) {
    Map<String, Object> a = findOrThrow(auctionId);
    if (!"draft".equals(a.get("status"))) throw ApiException.badRequest("Зөвхөн draft auction нийтлэх боломжтой.");
    boolean live = !((Instant) a.get("startsAt")).isAfter(Instant.now());
    db.sql("UPDATE auctions SET status = CAST(? AS \"AuctionStatus\"), updated_at = now() WHERE id = ?")
        .params(live ? "live" : "scheduled", auctionId)
        .update();
    if (live) realtime.emitToAuction(auctionId, "auction_started", Map.of("auctionId", auctionId));
    // Эхлэх/дуусах хугацааг AuctionScheduler өөрөө DB-ээс олж ажиллуулна (job товлох шаардлагагүй)
    return Map.of("ok", true);
  }

  public Map<String, Object> cancel(String auctionId) {
    Map<String, Object> a = findOrThrow(auctionId);
    if (!List.of("draft", "scheduled", "live").contains(a.get("status"))) {
      throw ApiException.badRequest("Энэ төлөвт цуцлах боломжгүй.");
    }
    db.sql("UPDATE auctions SET status = 'cancelled', updated_at = now() WHERE id = ?").param(auctionId).update();
    realtime.emitToAuction(auctionId, "auction_cancelled", Map.of("auctionId", auctionId));
    return Map.of("ok", true);
  }

  Map<String, Object> findOrThrow(String id) {
    return db.sql("SELECT id, status, starts_at, ends_at FROM auctions WHERE id = ?")
        .param(id)
        .query(rows.camel())
        .optional()
        .orElseThrow(() -> ApiException.notFound("Дуудлага худалдаа олдсонгүй"));
  }

  // ---------- Lifecycle (scheduler) ----------

  /** scheduled -> live болох хугацаа нь болсон auction-уудыг эхлүүлнэ. */
  public void startDue() {
    List<String> started =
        db.sql(
                "UPDATE auctions SET status = 'live', updated_at = now()"
                    + " WHERE status = 'scheduled' AND starts_at <= now() RETURNING id")
            .query(String.class)
            .list();
    for (String id : started) {
      realtime.emitToAuction(id, "auction_started", Map.of("auctionId", id));
      log.info("Auction {} started", id);
    }
  }

  /** Хугацаа нь дууссан live auction-уудын id. */
  public List<String> dueForFinalize(int limit) {
    return db.sql("SELECT id FROM auctions WHERE status = 'live' AND ends_at <= now() ORDER BY ends_at LIMIT ?")
        .param(limit)
        .query(String.class)
        .list();
  }

  /**
   * Auction-ыг хааж ялагчийг тодруулна (NestJS handleFinalize). SKIP LOCKED тул
   * consumer тухайн мөрийг түгжиж байвал энэ удаад алгасаад дараагийн tick-д оролдоно.
   */
  public void finalizeAuction(String auctionId) {
    Map<String, Object> outcome =
        tx.execute(
            s -> {
              Map<String, Object> row =
                  db.sql(
                          "SELECT id, status, ends_at, current_price, last_bidder_id FROM auctions"
                              + " WHERE id = ? FOR UPDATE SKIP LOCKED")
                      .param(auctionId)
                      .query(rows.camel())
                      .optional()
                      .orElse(null);
              if (row == null || !"live".equals(row.get("status"))) return null;
              // Soft close-оор сунгагдсан бол дараагийн tick хүртэл хүлээнэ
              if (((Instant) row.get("endsAt")).isAfter(Instant.now())) return null;

              db.sql("UPDATE auctions SET status = 'ended', updated_at = now() WHERE id = ?").param(auctionId).update();
              Map<String, Object> out = new LinkedHashMap<>();
              String winner = (String) row.get("lastBidderId");
              out.put("winner", winner);
              out.put("finalPrice", winner == null ? null : row.get("currentPrice"));
              if (winner != null) {
                String orderId = Ids.uuid();
                Instant deadline = Instant.now().plusSeconds(payDeadlineHours * 3600L);
                db.sql(
                        "INSERT INTO orders (id, auction_id, winner_id, final_price, pay_deadline, status, updated_at)"
                            + " VALUES (?, ?, ?, ?, ?, 'pending', now())")
                    .params(orderId, auctionId, winner, row.get("currentPrice"), Rows.ts(deadline))
                    .update();
                out.put("orderId", orderId);
                out.put("payDeadline", deadline.toString());
              }
              return out;
            });
    if (outcome == null) return;

    Map<String, Object> ended = new LinkedHashMap<>();
    ended.put("auctionId", auctionId);
    ended.put("winnerId", outcome.get("winner"));
    ended.put("finalPrice", outcome.get("finalPrice"));
    realtime.emitToAuction(auctionId, "auction_ended", ended);
    if (outcome.get("winner") != null) {
      Map<String, Object> won = new LinkedHashMap<>();
      won.put("auctionId", auctionId);
      won.put("orderId", outcome.get("orderId"));
      won.put("finalPrice", outcome.get("finalPrice"));
      won.put("payDeadline", outcome.get("payDeadline"));
      realtime.emitToUser((String) outcome.get("winner"), "auction_won", won);
    }
    log.info("Auction {} ended, winner={}", auctionId, outcome.get("winner") == null ? "байхгүй" : outcome.get("winner"));
  }

  /** Төлбөрийн хугацаа хэтэрсэн захиалгуудыг expired болгоно. */
  public void expireOrders() {
    List<String> expired =
        db.sql(
                "UPDATE orders SET status = 'expired', updated_at = now()"
                    + " WHERE status = 'pending' AND pay_deadline <= now() RETURNING id")
            .query(String.class)
            .list();
    for (String id : expired) log.info("Order {} expired (төлбөр хийгдээгүй)", id);
  }
}
