package mn.eduud.content;

import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.AuthAnnotations.Public;
import mn.eduud.config.AppProperties;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@Public
@RestController
public class ContentController {
  private final JdbcClient db;
  private final Rows rows;
  private final AppProperties props;

  public ContentController(JdbcClient db, Rows rows, AppProperties props) {
    this.db = db;
    this.rows = rows;
    this.props = props;
  }

  /** terms | privacy | faq */
  @GetMapping("/content/{key}")
  public Map<String, Object> content(@PathVariable String key) {
    return db.sql("SELECT key, title, body, updated_at FROM app_content WHERE key = ?")
        .param(key)
        .query(rows.camel())
        .optional()
        .orElseThrow(() -> ApiException.notFound("Контент олдсонгүй"));
  }

  /**
   * Апп ажиллах орчны төлөв. Нууц утга задруулахгүй — зөвхөн "энэ орчинд тест хийж
   * болно" гэдгийг апп-д мэдэгдэнэ.
   */
  @GetMapping("/config")
  public Map<String, Object> config() {
    return Map.of(
        "otpTestMode", props.otp().isMock(),
        "paymentTestMode", props.wire().isTest());
  }
}
