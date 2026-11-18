package mn.eduud.auctions;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.DistributionSummary;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import mn.eduud.auctions.AuctionLogic.Rejection;
import mn.eduud.auctions.AuctionLogic.Snapshot;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.realtime.RealtimeGateway;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Саналын цөм логик. Kafka consumer болон direct горим хоёулаа үүнийг ашигладаг тул
 * хоёр горимын ялгаа нь зөвхөн "queue байгаа эсэх" болно (шударга харьцуулалт).
 *
 * <p>Багцыг НЭГ транзакцаар боловсруулна:
 * <ol>
 *   <li>Давхардсан message-ийг bid_requests-ээс таньж алгасна (idempotency)</li>
 *   <li>Багцад орсон auction-уудыг, дараа нь wallet-уудыг id-ийн дарааллаар түгжинэ
 *       (тогтмол дараалал = deadlock-гүй)</li>
 *   <li>Санал бүрийг ирсэн дарааллаар санах ойд үнэлнэ</li>
 *   <li>Үр дүнг batch INSERT/UPDATE-ээр бичнэ</li>
 * </ol>
 * Нэг partition-ийг нэг consumer л уншдаг тул auction-ы түгжээ бараг хүлээлтгүй.
 * Багц том байх тусам нэг санал дахь DB-ийн зардал багасна — hot auction-ы throughput
 * үүгээр өсдөг.
 */
@Service
public class BidProcessor {
  private final JdbcClient db;
  private final JdbcTemplate jdbc;
  private final Rows rows;
  private final TransactionTemplate tx;
  private final RealtimeGateway realtime;

  private final Counter accepted;
  private final Counter rejected;
  private final Counter duplicates;
  private final Timer endToEnd;
  private final DistributionSummary batchSize;

  public BidProcessor(
      JdbcClient db, JdbcTemplate jdbc, Rows rows, TransactionTemplate tx, RealtimeGateway realtime, MeterRegistry m) {
    this.db = db;
    this.jdbc = jdbc;
    this.rows = rows;
    this.tx = tx;
    this.realtime = realtime;
    this.accepted = Counter.builder("bids.processed").tag("result", "accepted").register(m);
    this.rejected = Counter.builder("bids.processed").tag("result", "rejected").register(m);
    this.duplicates = Counter.builder("bids.processed").tag("result", "duplicate").register(m);
    this.endToEnd =
        Timer.builder("bids.end_to_end")
            .description("API хүлээн авснаас DB-д бичигдэх хүртэлх хугацаа")
            .publishPercentiles(0.5, 0.95, 0.99)
            .register(m);
    this.batchSize = DistributionSummary.builder("bids.batch_size").register(m);
  }

  /** Боловсруулах нэг message ба Kafka дахь байрлал (direct горимд null). */
  public record Incoming(BidCommand cmd, Integer partition, Long offset) {}

  public sealed interface Outcome permits Accepted, Rejected, Duplicate {
    BidCommand cmd();
  }

  public record Accepted(
      BidCommand cmd,
      int price,
      Instant endsAt,
      boolean extended,
      String previousBidderId,
      int bidCount,
      int newBalance,
      Map<String, Object> bidder)
      implements Outcome {}

  public record Rejected(BidCommand cmd, Rejection reason) implements Outcome {}

  public record Duplicate(BidCommand cmd) implements Outcome {}

  /** Багцыг нэг транзакцаар боловсруулж, commit болсны дараа realtime event-үүдийг цацна. */
  public List<Outcome> process(List<Incoming> batch) {
    List<Outcome> outcomes = tx.execute(s -> processInTx(batch));
    afterCommit(outcomes);
    return outcomes;
  }

  private List<Outcome> processInTx(List<Incoming> batch) {
    Instant now = Instant.now();

    // 1. Idempotency: өмнө нь боловсруулсан bid_id-уудыг алгасна
    String[] ids = batch.stream().map(i -> i.cmd().bidId()).distinct().toArray(String[]::new);
    Set<String> seen =
        new HashSet<>(db.sql("SELECT bid_id FROM bid_requests WHERE bid_id = ANY(?)").param(ids).query(String.class).list());

    // 2. Auction-уудыг id дарааллаар түгжинэ
    String[] auctionIds =
        new TreeSet<>(batch.stream().map(i -> i.cmd().auctionId()).toList()).toArray(String[]::new);
    Map<String, Snapshot> auctions = new HashMap<>();
    db.sql(
            "SELECT id, status, starts_at, ends_at, current_price, increment, soft_close_sec, extend_sec,"
                + " hard_close_at, last_bidder_id, bid_count, rounds::text AS rounds FROM auctions WHERE id = ANY(?) ORDER BY id FOR UPDATE")
        .param(auctionIds)
        .query(rows.camel())
        .list()
        .forEach(r -> auctions.put((String) r.get("id"), AuctionLogic.fromRow(r)));

    // 3. Wallet-уудыг user_id дарааллаар түгжинэ (auction -> wallet гэсэн тогтмол дараалал)
    String[] userIds = new TreeSet<>(batch.stream().map(i -> i.cmd().userId()).toList()).toArray(String[]::new);
    Map<String, Integer> balances = new HashMap<>();
    db.sql("SELECT user_id, balance FROM wallets WHERE user_id = ANY(?) ORDER BY user_id FOR UPDATE")
        .param(userIds)
        .query(rows.camel())
        .list()
        .forEach(r -> balances.put((String) r.get("userId"), ((Number) r.get("balance")).intValue()));
    Map<String, Map<String, Object>> bidders = new HashMap<>();
    db.sql("SELECT id, name, avatar_url FROM users WHERE id = ANY(?)")
        .param(userIds)
        .query(rows.camel())
        .list()
        .forEach(r -> bidders.put((String) r.get("id"), r));

    // 4. Ирсэн дарааллаар үнэлнэ
    List<Outcome> outcomes = new ArrayList<>(batch.size());
    List<Object[]> bidRows = new ArrayList<>();
    List<Object[]> ledgerRows = new ArrayList<>();
    List<Object[]> requestRows = new ArrayList<>();
    Set<String> changedAuctions = new LinkedHashSet<>();
    Set<String> changedWallets = new LinkedHashSet<>();

    for (Incoming in : batch) {
      BidCommand c = in.cmd();
      if (!seen.add(c.bidId())) {
        outcomes.add(new Duplicate(c));
        continue;
      }
      Instant receivedAt = Instant.ofEpochMilli(c.receivedAtMs());
      Snapshot a = auctions.get(c.auctionId());
      Rejection rejection;
      if (a == null) {
        rejection = Rejection.NOT_FOUND;
      } else {
        rejection = AuctionLogic.validateBid(a, c.userId(), receivedAt);
        if (rejection == null && balances.getOrDefault(c.userId(), 0) < 1) rejection = Rejection.NO_TOKENS;
      }
      if (rejection != null) {
        outcomes.add(new Rejected(c, rejection));
        requestRows.add(requestRow(in, "REJECTED", rejection.name(), now));
        continue;
      }

      // Хүлээн авна: санах ойн төлөвийг шинэчилнэ
      String previous = a.lastBidderId;
      Instant newEndsAt = AuctionLogic.computeNewEndsAt(a, receivedAt);
      boolean extended = !newEndsAt.equals(a.endsAt);
      a.currentPrice += a.increment;
      a.endsAt = newEndsAt;
      a.lastBidderId = c.userId();
      a.bidCount += 1;
      int balance = balances.get(c.userId()) - 1;
      balances.put(c.userId(), balance);
      changedAuctions.add(c.auctionId());
      changedWallets.add(c.userId());

      bidRows.add(
          new Object[] {
            c.bidId(), c.auctionId(), c.userId(), a.currentPrice, Rows.ts(now), Rows.ts(receivedAt), in.partition(), in.offset()
          });
      ledgerRows.add(new Object[] {Ids.uuid(), c.userId(), c.bidId(), "Санал: " + a.currentPrice + "₮", Rows.ts(now)});
      requestRows.add(requestRow(in, "ACCEPTED", null, now));
      outcomes.add(
          new Accepted(
              c,
              a.currentPrice,
              newEndsAt,
              extended,
              previous,
              a.bidCount,
              balance,
              bidderOf(bidders.get(c.userId()), c.userId())));
    }

    // 5. Batch бичилт
    if (!bidRows.isEmpty()) {
      jdbc.batchUpdate(
          "INSERT INTO bids (id, auction_id, user_id, price, created_at, received_at, kafka_partition, kafka_offset)"
              + " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
          bidRows);
      jdbc.batchUpdate(
          "INSERT INTO token_transactions (id, user_id, amount, type, ref_id, note, created_at)"
              + " VALUES (?, ?, -1, 'bid', ?, ?, ?)",
          ledgerRows);
    }
    List<Object[]> walletUpdates = new ArrayList<>();
    for (String u : changedWallets) walletUpdates.add(new Object[] {balances.get(u), u});
    if (!walletUpdates.isEmpty()) {
      jdbc.batchUpdate("UPDATE wallets SET balance = ?, updated_at = now() WHERE user_id = ?", walletUpdates);
    }
    List<Object[]> auctionUpdates = new ArrayList<>();
    for (String id : changedAuctions) {
      Snapshot a = auctions.get(id);
      auctionUpdates.add(new Object[] {a.currentPrice, Rows.ts(a.endsAt), a.lastBidderId, a.bidCount, id});
    }
    if (!auctionUpdates.isEmpty()) {
      jdbc.batchUpdate(
          "UPDATE auctions SET current_price = ?, ends_at = ?, last_bidder_id = ?, bid_count = ?, updated_at = now()"
              + " WHERE id = ?",
          auctionUpdates);
    }
    if (!requestRows.isEmpty()) {
      jdbc.batchUpdate(
          "INSERT INTO bid_requests (bid_id, auction_id, user_id, status, reason, received_at, processed_at,"
              + " kafka_partition, kafka_offset) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT (bid_id) DO NOTHING",
          requestRows);
    }
    return outcomes;
  }

  private static Object[] requestRow(Incoming in, String status, String reason, Instant now) {
    BidCommand c = in.cmd();
    return new Object[] {
      c.bidId(),
      c.auctionId(),
      c.userId(),
      status,
      reason,
      Rows.ts(Instant.ofEpochMilli(c.receivedAtMs())),
      Rows.ts(now),
      in.partition(),
      in.offset()
    };
  }

  private static Map<String, Object> bidderOf(Map<String, Object> row, String userId) {
    Map<String, Object> b = new LinkedHashMap<>();
    b.put("id", userId);
    b.put("name", row == null ? null : row.get("name"));
    b.put("avatarUrl", row == null ? null : row.get("avatarUrl"));
    return b;
  }

  /** Commit болсны дараах realtime event-үүд ба метрикүүд (NestJS-тэй ижил event нэр, payload). */
  private void afterCommit(List<Outcome> outcomes) {
    if (outcomes == null) return;
    batchSize.record(outcomes.size());
    long nowMs = System.currentTimeMillis();
    Map<String, Integer> finalBalances = new LinkedHashMap<>();

    for (Outcome o : outcomes) {
      if (o instanceof Accepted a) {
          accepted.increment();
          endToEnd.record(Duration.ofMillis(Math.max(0, nowMs - a.cmd().receivedAtMs())));
          String auctionId = a.cmd().auctionId();
          Map<String, Object> placed = new LinkedHashMap<>();
          placed.put("auctionId", auctionId);
          placed.put("price", a.price());
          placed.put("endsAt", a.endsAt().toString());
          placed.put("bidCount", a.bidCount());
          placed.put("bidder", a.bidder());
          realtime.emitToAuction(auctionId, "bid_placed", placed);
          if (a.extended()) {
            realtime.emitToAuction(auctionId, "auction_extended", Map.of("auctionId", auctionId, "endsAt", a.endsAt().toString()));
          }
          // Өөрийн дараалсан саналд outbid мэдэгдэл илгээхгүй
          if (a.previousBidderId() != null && !a.previousBidderId().equals(a.cmd().userId())) {
            realtime.emitToUser(a.previousBidderId(), "outbid", Map.of("auctionId", auctionId, "price", a.price()));
          }
          finalBalances.put(a.cmd().userId(), a.newBalance());
      } else if (o instanceof Rejected r) {
          rejected.increment();
          Map<String, Object> p = new LinkedHashMap<>();
          p.put("auctionId", r.cmd().auctionId());
          p.put("bidId", r.cmd().bidId());
          p.put("reason", r.reason().name());
          p.put("message", r.reason().message);
          realtime.emitToUser(r.cmd().userId(), "bid_rejected", p);
      } else {
        duplicates.increment();
      }
    }
    finalBalances.forEach((userId, balance) -> realtime.emitToUser(userId, "wallet_updated", Map.of("balance", balance)));
  }
}
