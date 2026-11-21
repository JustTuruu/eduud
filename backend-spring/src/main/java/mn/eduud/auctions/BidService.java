package mn.eduud.auctions;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import mn.eduud.auctions.AuctionLogic.Rejection;
import mn.eduud.auctions.AuctionLogic.Snapshot;
import mn.eduud.auctions.BidProcessor.Accepted;
import mn.eduud.auctions.BidProcessor.Incoming;
import mn.eduud.auctions.BidProcessor.Outcome;
import mn.eduud.auctions.BidProcessor.Rejected;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

/**
 * POST /auctions/:id/bid.
 *
 * <ul>
 *   <li><b>kafka</b> горим: түгжээгүй урьдчилсан шалгалт → `auction.bids` руу key=auctionId-тай
 *       илгээж broker-ийн ack (acks=all) авмагц 202 Accepted {bidId, PENDING} буцаана.
 *       Эцсийн үр дүн socket-оор (bid_placed / bid_rejected) ирнэ.</li>
 *   <li><b>direct</b> горим: NestJS-тэй адил хүсэлтийн дотор транзакц хийгээд 200 буцаана.</li>
 * </ul>
 */
@Service
public class BidService {
  private static final Logger log = LoggerFactory.getLogger(BidService.class);

  private final JdbcClient db;
  private final Rows rows;
  private final BidProcessor processor;
  private final KafkaTemplate<String, BidCommand> kafka;
  private final AppProperties.Bid cfg;

  public BidService(
      JdbcClient db,
      Rows rows,
      BidProcessor processor,
      ObjectProvider<KafkaTemplate<String, BidCommand>> kafka,
      AppProperties props) {
    this.db = db;
    this.rows = rows;
    this.processor = processor;
    this.kafka = kafka.getIfAvailable();
    this.cfg = props.bid();
  }

  public ResponseEntity<Map<String, Object>> placeBid(String auctionId, String userId, Integer step) {
    if (!AuctionLogic.validStep(step)) throw ApiException.badRequest("Алхам 1–5 ₮ байх ёстой");
    BidCommand cmd =
        new BidCommand(
            Ids.uuid(), auctionId, userId, System.currentTimeMillis(), BidCommand.SCHEMA_VERSION, step);
    return cfg.isKafka() ? enqueue(cmd) : direct(cmd);
  }

  // ---------- Kafka горим ----------

  private ResponseEntity<Map<String, Object>> enqueue(BidCommand cmd) {
    precheck(cmd);
    try {
      kafka.send(cfg.topic(), cmd.auctionId(), cmd).get(cfg.produceTimeoutMs(), TimeUnit.MILLISECONDS);
    } catch (Exception e) {
      log.warn("Санал queue-д илгээгдсэнгүй: {}", e.getMessage());
      // Санал зарцуулагдаагүй — хэрэглэгч дахин оролдож болно (FR-18)
      throw ApiException.unavailable("Санал хүлээн авах боломжгүй байна. Дахин оролдоно уу.");
    }
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("ok", true);
    body.put("status", "PENDING");
    body.put("bidId", cmd.bidId());
    return ResponseEntity.status(HttpStatus.ACCEPTED).body(body);
  }

  /**
   * Түгжээгүй, хурдан урьдчилсан шалгалт: илт буруу саналыг queue-д оруулахгүй.
   * Эцсийн шийдвэрийг consumer гаргана (энэ мэдээлэл хуучирсан байж болно).
   */
  private void precheck(BidCommand cmd) {
    Map<String, Object> r =
        db.sql(
                "SELECT a.status, a.starts_at, a.ends_at, a.secret_close_at, a.last_bidder_id,"
                    + " (SELECT balance FROM wallets WHERE user_id = ?) AS balance"
                    + " FROM auctions a WHERE a.id = ?")
            .params(cmd.userId(), cmd.auctionId())
            .query(rows.camel())
            .optional()
            .orElseThrow(() -> ApiException.notFound(Rejection.NOT_FOUND.message));
    Snapshot s = new Snapshot();
    s.status = (String) r.get("status");
    s.startsAt = (Instant) r.get("startsAt");
    s.endsAt = (Instant) r.get("endsAt");
    s.secretCloseAt = (Instant) r.get("secretCloseAt");
    s.lastBidderId = (String) r.get("lastBidderId");
    Rejection rej = AuctionLogic.validateBid(s, cmd.userId(), Instant.ofEpochMilli(cmd.receivedAtMs()));
    if (rej != null) throw ApiException.badRequest(rej.message);
    Object balance = r.get("balance");
    if (balance == null || ((Number) balance).intValue() < 1) throw ApiException.badRequest(Rejection.NO_TOKENS.message);
  }

  // ---------- Direct горим (суурь хувилбар) ----------

  private ResponseEntity<Map<String, Object>> direct(BidCommand cmd) {
    List<Outcome> outcomes = processor.process(List.of(new Incoming(cmd, null, null)));
    Outcome o = outcomes.get(0);
    if (o instanceof Rejected r) {
      if (r.reason() == Rejection.NOT_FOUND) throw ApiException.notFound(r.reason().message);
      throw ApiException.badRequest(r.reason().message);
    }
    Accepted a = (Accepted) o;
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("ok", true);
    body.put("price", a.price());
    body.put("endsAt", a.endsAt().toString());
    body.put("balance", a.newBalance());
    return ResponseEntity.ok(body);
  }
}
