package mn.eduud.payments;

import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.realtime.RealtimeGateway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Төлбөр батлагдсаны дараах нэгдсэн settle логик.
 * Idempotent: `pending -> paid` шилжилт нөхцөлтэй UPDATE-ээр зөвхөн нэг удаа амжина —
 * webhook давхар ирсэн ч token давхар нэмэгдэхгүй.
 */
@Service
public class PaymentsService {
  private static final Logger log = LoggerFactory.getLogger(PaymentsService.class);

  private final JdbcClient db;
  private final Rows rows;
  private final TransactionTemplate tx;
  private final WireService wire;
  private final RealtimeGateway realtime;

  public PaymentsService(JdbcClient db, Rows rows, TransactionTemplate tx, WireService wire, RealtimeGateway realtime) {
    this.db = db;
    this.rows = rows;
    this.tx = tx;
    this.wire = wire;
    this.realtime = realtime;
  }

  public Map<String, Object> settleByInvoiceId(String wireInvoiceId, Object rawWebhook) {
    String paymentId =
        db.sql("SELECT id FROM payments WHERE wire_invoice_id = ?")
            .param(wireInvoiceId)
            .query(String.class)
            .optional()
            .orElseThrow(() -> ApiException.notFound("Invoice олдсонгүй"));
    return settle(paymentId, rawWebhook);
  }

  private record Settled(String userId, String kind, String orderId, Integer newBalance) {}

  public Map<String, Object> settle(String paymentId, Object rawWebhook) {
    Settled result =
        tx.execute(
            s -> {
              // Idempotency guard: pending -> paid шилжилт зөвхөн нэг удаа амжина
              int updated =
                  db.sql(
                          "UPDATE payments SET status = 'paid', paid_at = now(),"
                              + " raw_webhook = COALESCE(CAST(? AS jsonb), raw_webhook)"
                              + " WHERE id = ? AND status = 'pending'")
                      .params(rows.toJson(rawWebhook), paymentId)
                      .update();
              if (updated == 0) return null; // аль хэдийн боловсруулсан

              Map<String, Object> p =
                  db.sql(
                          "SELECT p.user_id, p.kind, p.order_id, tp.tokens FROM payments p"
                              + " LEFT JOIN token_packages tp ON tp.id = p.package_id WHERE p.id = ?")
                      .param(paymentId)
                      .query(rows.camel())
                      .single();
              String userId = (String) p.get("userId");
              String kind = (String) p.get("kind");

              if ("topup".equals(kind)) {
                Object tokens = p.get("tokens");
                if (tokens == null) throw new IllegalStateException("Payment " + paymentId + ": package алга");
                int t = ((Number) tokens).intValue();
                Integer balance =
                    db.sql(
                            "UPDATE wallets SET balance = balance + ?, updated_at = now() WHERE user_id = ?"
                                + " RETURNING balance")
                        .params(t, userId)
                        .query(Integer.class)
                        .single();
                db.sql(
                        "INSERT INTO token_transactions (id, user_id, amount, type, ref_id, note)"
                            + " VALUES (?, ?, ?, 'purchase', ?, ?)")
                    .params(Ids.uuid(), userId, t, paymentId, t + " token цэнэглэлт")
                    .update();
                return new Settled(userId, kind, null, balance);
              }
              String orderId = (String) p.get("orderId");
              if ("order".equals(kind) && orderId != null) {
                db.sql("UPDATE orders SET status = 'paid', updated_at = now() WHERE id = ?").param(orderId).update();
              }
              return new Settled(userId, kind, orderId, null);
            });

    if (result != null) {
      if (result.newBalance() != null) {
        realtime.emitToUser(result.userId(), "wallet_updated", Map.of("balance", result.newBalance()));
      } else {
        Map<String, Object> m = new java.util.LinkedHashMap<>();
        m.put("orderId", result.orderId());
        realtime.emitToUser(result.userId(), "order_paid", m);
      }
      log.info("Payment {} settled ({})", paymentId, result.kind());
    }
    return Map.of("ok", true);
  }

  /** Fallback: хэрэглэгч "төлбөр шалгах" дарахад wire.mn-ээс лавлаж settle хийнэ. */
  public Map<String, Object> checkAndSettle(String userId, String paymentId) {
    Map<String, Object> payment =
        db.sql("SELECT id, status, wire_invoice_id FROM payments WHERE id = ? AND user_id = ?")
            .params(paymentId, userId)
            .query(rows.camel())
            .optional()
            .orElseThrow(() -> ApiException.notFound("Төлбөр олдсонгүй"));
    if ("paid".equals(payment.get("status"))) return Map.of("status", "paid");
    String invoiceId = (String) payment.get("wireInvoiceId");
    if (invoiceId == null) throw ApiException.badRequest("Invoice үүсээгүй");

    String status = wire.inquiry(invoiceId);
    if ("paid".equals(status)) {
      settle(paymentId, null);
      return Map.of("status", "paid");
    }
    return Map.of("status", status);
  }
}
