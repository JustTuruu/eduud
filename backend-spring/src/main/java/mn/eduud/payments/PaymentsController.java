package mn.eduud.payments;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.AuthAnnotations.Public;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/payments")
public class PaymentsController {
  private final PaymentsService payments;
  private final WireService wire;
  private final Rows rows;

  public PaymentsController(PaymentsService payments, WireService wire, Rows rows) {
    this.payments = payments;
    this.wire = wire;
    this.rows = rows;
  }

  /**
   * wire.mn webhook. Body-г raw string-ээр авч signature шалгана.
   * TODO(wire.mn): payload-ын бүтцийг албан ёсны бичиг баримттай тулгах.
   */
  @Public
  @PostMapping("/wire/webhook")
  public Map<String, Object> webhook(
      @RequestBody String raw, @RequestHeader(value = "x-wire-signature", required = false) String signature) {
    wire.verifyWebhookSignature(raw, signature);
    JsonNode body = rows.parseJson(raw);
    String invoiceId =
        body.hasNonNull("invoice_id")
            ? body.get("invoice_id").asText()
            : body.hasNonNull("invoiceId") ? body.get("invoiceId").asText() : body.path("id").asText(null);
    String status = body.path("status").asText("").toUpperCase();
    if (invoiceId != null && (status.equals("PAID") || status.equals("SUCCESS"))) {
      payments.settleByInvoiceId(invoiceId, body);
    }
    return Map.of("ok", true);
  }

  /** Зөвхөн WIRE_MODE=test үед: төлбөрийг гараар "төлөгдсөн" болгож симуляци хийнэ. */
  @Public
  @PostMapping("/wire/test-pay/{invoiceId}")
  public Map<String, Object> testPay(@PathVariable String invoiceId) {
    if (!wire.isTest()) throw ApiException.forbidden("Test горимд л ажиллана");
    payments.settleByInvoiceId(invoiceId, Map.of("simulated", true));
    return Map.of("ok", true);
  }
}
