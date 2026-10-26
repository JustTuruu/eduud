package mn.eduud.payments;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * wire.mn төлбөрийн gateway adapter. WIRE_MODE=test үед invoice-г локал симуляци хийнэ,
 * live үед wire.mn REST API дуудна.
 *
 * TODO(wire.mn): merchant бүртгэл баталгаажсаны дараа endpoint/талбаруудыг албан ёсны
 * API бичиг баримттай тулгах (NestJS хувилбартай ижил TODO).
 */
@Service
public class WireService {
  private static final Logger log = LoggerFactory.getLogger(WireService.class);

  public record WireInvoice(String invoiceId, String qrText, String qrImageUrl, String deeplink) {}

  private final AppProperties.Wire cfg;
  private final ObjectMapper mapper;
  private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

  public WireService(AppProperties props, ObjectMapper mapper) {
    this.cfg = props.wire();
    this.mapper = mapper;
  }

  public boolean isTest() {
    return cfg.isTest();
  }

  public WireInvoice createInvoice(int amountMnt, String description, String referenceId) {
    if (cfg.isTest()) {
      String invoiceId = "test_" + Ids.uuid();
      log.warn("[WIRE TEST] invoice {} — {}₮ ({})", invoiceId, amountMnt, description);
      return new WireInvoice(
          invoiceId, "WIRE-TEST:" + invoiceId + ":" + amountMnt, null, "eduud://payment/test/" + invoiceId);
    }
    try {
      Map<String, Object> body = new LinkedHashMap<>();
      body.put("amount", amountMnt);
      body.put("currency", "MNT");
      body.put("description", description);
      body.put("reference_id", referenceId);
      HttpResponse<String> res =
          http.send(
              HttpRequest.newBuilder(URI.create(cfg.apiUrl() + "/v1/invoices"))
                  .header("Content-Type", "application/json")
                  .header("Authorization", "Bearer " + cfg.apiKey())
                  .POST(HttpRequest.BodyPublishers.ofString(mapper.writeValueAsString(body)))
                  .build(),
              HttpResponse.BodyHandlers.ofString());
      if (res.statusCode() >= 300) {
        throw new IllegalStateException("wire.mn invoice үүсгэхэд алдаа: " + res.statusCode() + " " + res.body());
      }
      JsonNode d = mapper.readTree(res.body());
      return new WireInvoice(
          d.path("id").asText(), d.path("qr_text").asText(null), d.path("qr_image").asText(null), d.path("deeplink").asText(null));
    } catch (RuntimeException e) {
      throw e;
    } catch (Exception e) {
      throw new IllegalStateException(e.getMessage(), e);
    }
  }

  /** Invoice-ийн төлөвийг wire.mn-ээс лавлана: paid | pending | failed. */
  public String inquiry(String invoiceId) {
    // Test горимд /payments/wire/test-pay-ээр "төлсөн" болгодог тул үргэлж pending
    if (cfg.isTest()) return "pending";
    try {
      HttpResponse<String> res =
          http.send(
              HttpRequest.newBuilder(URI.create(cfg.apiUrl() + "/v1/invoices/" + invoiceId))
                  .header("Authorization", "Bearer " + cfg.apiKey())
                  .GET()
                  .build(),
              HttpResponse.BodyHandlers.ofString());
      if (res.statusCode() >= 300) throw new IllegalStateException("wire.mn inquiry алдаа: " + res.statusCode());
      String status = mapper.readTree(res.body()).path("status").asText("");
      return "PAID".equals(status) ? "paid" : "FAILED".equals(status) ? "failed" : "pending";
    } catch (RuntimeException e) {
      throw e;
    } catch (Exception e) {
      throw new IllegalStateException(e.getMessage(), e);
    }
  }

  /** Webhook-ийн HMAC-SHA256 гарын үсгийг шалгана (constant-time харьцуулалт). */
  public void verifyWebhookSignature(String rawBody, String signature) {
    if (cfg.isTest()) return;
    if (signature == null) throw ApiException.unauthorized("Signature алга");
    try {
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(nullToEmpty(cfg.webhookSecret()).getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
      String expected = HexFormat.of().formatHex(mac.doFinal(rawBody.getBytes(StandardCharsets.UTF_8)));
      if (!MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8), signature.getBytes(StandardCharsets.UTF_8))) {
        throw ApiException.unauthorized("Signature буруу");
      }
    } catch (ApiException e) {
      throw e;
    } catch (Exception e) {
      throw ApiException.unauthorized("Signature буруу");
    }
  }

  private static String nullToEmpty(String s) {
    return s == null ? "" : s;
  }
}
