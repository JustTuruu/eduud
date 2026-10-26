package mn.eduud.wallet;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthUser;
import mn.eduud.payments.PaymentsService;
import mn.eduud.payments.WireService;
import mn.eduud.payments.WireService.WireInvoice;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/wallet")
public class WalletController {
  static final String UUID_RE = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$";

  private final JdbcClient db;
  private final Rows rows;
  private final WireService wire;
  private final PaymentsService payments;

  public WalletController(JdbcClient db, Rows rows, WireService wire, PaymentsService payments) {
    this.db = db;
    this.rows = rows;
    this.wire = wire;
    this.payments = payments;
  }

  public record TopupDto(@NotNull @Pattern(regexp = UUID_RE, message = "packageId must be a UUID") String packageId) {}

  @GetMapping
  public Map<String, Object> balance(@CurrentUser AuthUser user) {
    Integer balance =
        db.sql("SELECT balance FROM wallets WHERE user_id = ?").param(user.id()).query(Integer.class).optional().orElse(0);
    return Map.of("balance", balance);
  }

  @GetMapping("/packages")
  public List<Map<String, Object>> packages() {
    return db.sql("SELECT id, tokens, price_mnt FROM token_packages WHERE active = true ORDER BY sort_order ASC")
        .query(rows.camel())
        .list();
  }

  @GetMapping("/transactions")
  public List<Map<String, Object>> transactions(@CurrentUser AuthUser user) {
    return db.sql(
            "SELECT id, amount, type, note, created_at FROM token_transactions WHERE user_id = ?"
                + " ORDER BY created_at DESC LIMIT 50")
        .param(user.id())
        .query(rows.camel())
        .list();
  }

  /** Багц сонгож wire.mn invoice үүсгэнэ. */
  @PostMapping("/topup")
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> topup(@CurrentUser AuthUser user, @Valid @RequestBody TopupDto dto) {
    Map<String, Object> pkg =
        db.sql("SELECT id, tokens, price_mnt FROM token_packages WHERE id = ? AND active = true")
            .param(dto.packageId())
            .query(rows.camel())
            .optional()
            .orElseThrow(() -> ApiException.notFound("Багц олдсонгүй"));
    int price = ((Number) pkg.get("priceMnt")).intValue();
    int tokens = ((Number) pkg.get("tokens")).intValue();

    String paymentId = Ids.uuid();
    db.sql(
            "INSERT INTO payments (id, user_id, kind, package_id, amount_mnt, status)"
                + " VALUES (?, ?, 'topup', ?, ?, 'pending')")
        .params(paymentId, user.id(), pkg.get("id"), price)
        .update();

    WireInvoice invoice;
    try {
      invoice = wire.createInvoice(price, "E-Duud: " + tokens + " token", paymentId);
    } catch (Exception e) {
      db.sql("UPDATE payments SET status = 'failed' WHERE id = ?").param(paymentId).update();
      throw ApiException.badRequest("Төлбөрийн нэхэмжлэх үүсгэж чадсангүй. Дахин оролдоно уу.");
    }
    db.sql("UPDATE payments SET wire_invoice_id = ? WHERE id = ?").params(invoice.invoiceId(), paymentId).update();

    Map<String, Object> res = new LinkedHashMap<>();
    res.put("paymentId", paymentId);
    res.put("invoiceId", invoice.invoiceId());
    res.put("amountMnt", price);
    res.put("tokens", tokens);
    res.put("qrText", invoice.qrText());
    res.put("qrImageUrl", invoice.qrImageUrl());
    res.put("deeplink", invoice.deeplink());
    return res;
  }

  /** Webhook алдагдсан үеийн fallback — төлбөрөө гараар шалгах. */
  @PostMapping("/topup/{paymentId}/check")
  public Map<String, Object> check(@CurrentUser AuthUser user, @PathVariable String paymentId) {
    return payments.checkAndSettle(user.id(), paymentId);
  }
}
