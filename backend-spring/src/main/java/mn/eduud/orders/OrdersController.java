package mn.eduud.orders;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthUser;
import mn.eduud.payments.PaymentsService;
import mn.eduud.payments.WireService;
import mn.eduud.payments.WireService.WireInvoice;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/orders")
public class OrdersController {
  private final JdbcClient db;
  private final Rows rows;
  private final WireService wire;
  private final PaymentsService payments;

  public OrdersController(JdbcClient db, Rows rows, WireService wire, PaymentsService payments) {
    this.db = db;
    this.rows = rows;
    this.wire = wire;
    this.payments = payments;
  }

  /** Prisma: `include: { auction: { select: { id, title, images } } }`. */
  @GetMapping
  public List<Map<String, Object>> myOrders(@CurrentUser AuthUser user) {
    return db.sql(
            "SELECT o.id, o.auction_id, o.winner_id, o.final_price, o.pay_deadline, o.status, o.delivery_info,"
                + " o.prize_place, o.prize_title, o.created_at, o.updated_at,"
                + " json_build_object('id', a.id, 'title', a.title, 'images', a.images) AS auction"
                + " FROM orders o JOIN auctions a ON a.id = o.auction_id WHERE o.winner_id = ?"
                + " ORDER BY o.created_at DESC")
        .param(user.id())
        .query(rows.camel())
        .list();
  }

  /** Ялсан барааны эцсийн үнийг төлөх wire.mn invoice үүсгэнэ. */
  @PostMapping("/{id}/pay")
  public Map<String, Object> pay(@CurrentUser AuthUser user, @PathVariable UUID id) {
    Map<String, Object> order =
        db.sql(
                "SELECT o.id, o.final_price, o.status, a.title, p.id AS payment_id, p.status AS payment_status,"
                    + " p.wire_invoice_id FROM orders o JOIN auctions a ON a.id = o.auction_id"
                    + " LEFT JOIN payments p ON p.order_id = o.id WHERE o.id = ? AND o.winner_id = ?")
            .params(id.toString(), user.id())
            .query(rows.camel())
            .optional()
            .orElseThrow(() -> ApiException.notFound("Захиалга олдсонгүй"));
    if ("paid".equals(order.get("status"))) throw ApiException.badRequest("Төлбөр аль хэдийн хийгдсэн.");
    if (!"pending".equals(order.get("status"))) throw ApiException.badRequest("Захиалгын хугацаа дууссан.");
    int finalPrice = ((Number) order.get("finalPrice")).intValue();

    // Өмнө үүсгэсэн pending invoice байвал түүнийгээ буцаана
    if ("pending".equals(order.get("paymentStatus")) && order.get("wireInvoiceId") != null) {
      Map<String, Object> res = new LinkedHashMap<>();
      res.put("paymentId", order.get("paymentId"));
      res.put("invoiceId", order.get("wireInvoiceId"));
      res.put("amountMnt", finalPrice);
      return res;
    }

    String paymentId = Ids.uuid();
    db.sql(
            "INSERT INTO payments (id, user_id, kind, order_id, amount_mnt, status)"
                + " VALUES (?, ?, 'order', ?, ?, 'pending')")
        .params(paymentId, user.id(), id.toString(), finalPrice)
        .update();
    WireInvoice invoice = wire.createInvoice(finalPrice, "E-Duud ялалт: " + order.get("title"), paymentId);
    db.sql("UPDATE payments SET wire_invoice_id = ? WHERE id = ?").params(invoice.invoiceId(), paymentId).update();

    Map<String, Object> res = new LinkedHashMap<>();
    res.put("paymentId", paymentId);
    res.put("invoiceId", invoice.invoiceId());
    res.put("amountMnt", finalPrice);
    res.put("qrText", invoice.qrText());
    res.put("qrImageUrl", invoice.qrImageUrl());
    res.put("deeplink", invoice.deeplink());
    return res;
  }

  @PostMapping("/{id}/payments/{paymentId}/check")
  public Map<String, Object> check(@CurrentUser AuthUser user, @PathVariable UUID id, @PathVariable UUID paymentId) {
    return payments.checkAndSettle(user.id(), paymentId.toString());
  }
}
