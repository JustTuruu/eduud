package mn.eduud.auctions;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import mn.eduud.auctions.PrizeRules.Prize;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

/**
 * 2/3-р байрны шагнал: тохиргооны CRUD, нийтийн харагдац, дуудлага дуусах үеийн олголт.
 * Байрын эрэмбэ нь ялагчийг тодруулдаг эрэмбэтэй ижил — саналын үнэ нь auction дотор зөвхөн өснө
 * (nextPrice >= +1), иймд `price DESC` нь саналын дарааллын шинэ -> хуучин юм.
 */
@Component
public class AuctionPrizes {
  /** Нийт 3 байр: 1 = ялагч, 2/3 = шагналтай байр. */
  static final int RUNNERS_UP = 2;

  /** Олгосон шагнал (tx дууссаны дараа socket-ээр мэдэгдэнэ). */
  public record Award(String userId, int place, String kind, Integer tokens, String title, Integer newBalance) {}

  private final JdbcClient db;
  private final Rows rows;

  public AuctionPrizes(JdbcClient db, Rows rows) {
    this.db = db;
    this.rows = rows;
  }

  // ---------- Тохиргоо ----------

  /** Мөр бүрийн `id`-аар `prizes` (place-ээр эрэмбэлсэн, байхгүй бол хоосон жагсаалт) нэмнэ. */
  public void attach(List<Map<String, Object>> auctionRows) {
    if (auctionRows.isEmpty()) return;
    String[] ids = auctionRows.stream().map(r -> (String) r.get("id")).toArray(String[]::new);
    Map<String, List<Map<String, Object>>> byAuction = new HashMap<>();
    for (Map<String, Object> p : prizeRows(ids)) {
      byAuction.computeIfAbsent((String) p.get("auctionId"), k -> new ArrayList<>()).add(publicPrize(p));
    }
    for (Map<String, Object> r : auctionRows) {
      r.put("prizes", byAuction.getOrDefault((String) r.get("id"), List.of()));
    }
  }

  public void attach(Map<String, Object> auctionRow) {
    List<Map<String, Object>> one = new ArrayList<>(List.of(auctionRow));
    attach(one);
  }

  /** Auction-ы шагналуудыг бүрэн солино (draft/scheduled үед л дуудна). */
  public void replace(String auctionId, List<Prize> prizes) {
    db.sql("DELETE FROM auction_prizes WHERE auction_id = ?").param(auctionId).update();
    for (Prize p : prizes) {
      db.sql("INSERT INTO auction_prizes (auction_id, place, kind, tokens, title) VALUES (?, ?, ?, ?, ?)")
          .params(auctionId, p.place(), p.kind(), p.tokens(), p.title())
          .update();
    }
  }

  private List<Map<String, Object>> prizeRows(String[] auctionIds) {
    return db.sql(
            "SELECT auction_id, place, kind, tokens, title FROM auction_prizes"
                + " WHERE auction_id = ANY(?) ORDER BY auction_id, place")
        .param(auctionIds)
        .query(rows.camel())
        .list();
  }

  private static Map<String, Object> publicPrize(Map<String, Object> p) {
    Map<String, Object> m = new LinkedHashMap<>();
    m.put("place", ((Number) p.get("place")).intValue());
    m.put("kind", p.get("kind"));
    m.put("tokens", p.get("tokens"));
    m.put("title", p.get("title"));
    return m;
  }

  // ---------- Байр ----------

  /** 2/3-р байрны хэрэглэгчид (шинэ санал түрүүлж; ялагчийг хассан, давхардалгүй). */
  public List<String> runnersUp(String auctionId, String winnerId) {
    List<String> newestFirst =
        db.sql(
                "SELECT user_id FROM bids WHERE auction_id = ? GROUP BY user_id"
                    + " ORDER BY max(price) DESC LIMIT ?")
            .params(auctionId, RUNNERS_UP + 2)
            .query(String.class)
            .list();
    return AuctionLogic.pickRunnersUp(newestFirst, winnerId, RUNNERS_UP);
  }

  /**
   * Дууссан auction-ы байрууд: `[{place, user:{id,name}, prize|null}]` — зөвхөн саналтай байрууд.
   * 1-р байрны prize үргэлж null (үндсэн бараа).
   */
  public List<Map<String, Object>> placements(String auctionId, String winnerId) {
    if (winnerId == null) return List.of();
    List<String> users = new ArrayList<>();
    users.add(winnerId);
    users.addAll(runnersUp(auctionId, winnerId));
    Map<String, String> names = new HashMap<>();
    db.sql("SELECT id, name FROM users WHERE id = ANY(?)")
        .param(users.toArray(String[]::new))
        .query(rows.camel())
        .list()
        .forEach(r -> names.put((String) r.get("id"), (String) r.get("name")));
    Map<Integer, Map<String, Object>> prizeByPlace = new HashMap<>();
    for (Map<String, Object> p : prizeRows(new String[] {auctionId})) {
      Map<String, Object> pub = publicPrize(p);
      Map<String, Object> shown = new LinkedHashMap<>();
      shown.put("kind", pub.get("kind"));
      shown.put("tokens", pub.get("tokens"));
      shown.put("title", pub.get("title"));
      prizeByPlace.put((Integer) pub.get("place"), shown);
    }
    List<Map<String, Object>> out = new ArrayList<>();
    for (int i = 0; i < users.size(); i++) {
      String uid = users.get(i);
      Map<String, Object> user = new LinkedHashMap<>();
      user.put("id", uid);
      user.put("name", names.get(uid));
      Map<String, Object> m = new LinkedHashMap<>();
      m.put("place", i + 1);
      m.put("user", user);
      m.put("prize", i == 0 ? null : prizeByPlace.get(i + 1));
      out.add(m);
    }
    return out;
  }

  // ---------- Олголт ----------

  /**
   * 2/3-р байрны шагналыг олгоно. Auction хаах транзакц дотор дуудна (auction мөр түгжигдсэн).
   * Idempotent: `awarded_at IS NULL` guard-тай UPDATE нэг л удаа амжина.
   * Wallet-уудыг user_id-ийн дарааллаар түгжинэ (BidProcessor-той deadlock-гүй).
   */
  public List<Award> award(String auctionId, String winnerId) {
    if (winnerId == null) return List.of();
    List<String> users = runnersUp(auctionId, winnerId);
    if (users.isEmpty()) return List.of();

    List<Map<String, Object>> pending =
        db.sql(
                "SELECT place, kind, tokens, title FROM auction_prizes"
                    + " WHERE auction_id = ? AND awarded_at IS NULL ORDER BY place")
            .param(auctionId)
            .query(rows.camel())
            .list();
    record Pick(String userId, Map<String, Object> prize) {}
    List<Pick> picks = new ArrayList<>();
    for (Map<String, Object> p : pending) {
      int idx = ((Number) p.get("place")).intValue() - 2;
      if (idx < users.size()) picks.add(new Pick(users.get(idx), p));
    }
    picks.sort(Comparator.comparing(Pick::userId));

    List<Award> awards = new ArrayList<>();
    for (Pick pk : picks) {
      int place = ((Number) pk.prize().get("place")).intValue();
      String kind = (String) pk.prize().get("kind");
      Integer tokens = (Integer) pk.prize().get("tokens");
      String title = (String) pk.prize().get("title");
      int claimed =
          db.sql(
                  "UPDATE auction_prizes SET awarded_user_id = ?, awarded_at = now()"
                      + " WHERE auction_id = ? AND place = ? AND awarded_at IS NULL")
              .params(pk.userId(), auctionId, place)
              .update();
      if (claimed == 0) continue;
      Integer balance = null;
      if ("tokens".equals(kind)) {
        balance =
            db.sql(
                    "INSERT INTO wallets (user_id, balance, updated_at) VALUES (?, ?, now())"
                        + " ON CONFLICT (user_id) DO UPDATE SET balance = wallets.balance + EXCLUDED.balance,"
                        + " updated_at = now() RETURNING balance")
                .params(pk.userId(), tokens)
                .query(Integer.class)
                .single();
        db.sql(
                "INSERT INTO token_transactions (id, user_id, amount, type, ref_id, note)"
                    + " VALUES (?, ?, ?, 'prize', ?, ?)")
            .params(Ids.uuid(), pk.userId(), tokens, auctionId, place + "-р байрны шагнал: " + tokens + " эрх")
            .update();
      } else {
        // Бараа: 0₮-ийн, аль хэдийн төлөгдсөн захиалга — админ ердийн хүргэлтийн урсгалаар хүргэнэ
        String orderId = Ids.uuid();
        db.sql(
                "INSERT INTO orders (id, auction_id, winner_id, final_price, pay_deadline, status,"
                    + " prize_place, prize_title, updated_at) VALUES (?, ?, ?, 0, ?, 'paid', ?, ?, now())")
            .params(orderId, auctionId, pk.userId(), Rows.ts(Instant.now()), place, title)
            .update();
        db.sql("UPDATE auction_prizes SET order_id = ? WHERE auction_id = ? AND place = ?")
            .params(orderId, auctionId, place)
            .update();
      }
      awards.add(new Award(pk.userId(), place, kind, tokens, title, balance));
    }
    return awards;
  }

  /** Socket payload-ууд: `prize_awarded` (+ токен бол `wallet_updated`) мэдэгдлийг илгээхэд ашиглана. */
  public static Map<String, Object> awardPayload(String auctionId, Award a) {
    Map<String, Object> m = new LinkedHashMap<>();
    m.put("auctionId", auctionId);
    m.put("place", a.place());
    m.put("kind", a.kind());
    m.put("tokens", a.tokens());
    m.put("title", a.title());
    return m;
  }
}
