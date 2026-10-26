package mn.eduud.common;

import com.fasterxml.jackson.databind.exc.UnrecognizedPropertyException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * Алдааны хариуг NestJS-тэй яг адил хэлбэрээр буцаана:
 * {"statusCode": 400, "message": "..." | ["..."], "error": "Bad Request"}.
 * Flutter апп `message`-ийг уншиж хэрэглэгчид харуулдаг.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {
  private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

  @ExceptionHandler(ApiException.class)
  public ResponseEntity<Map<String, Object>> api(ApiException e) {
    return body(e.status(), e.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<Map<String, Object>> validation(MethodArgumentNotValidException e) {
    List<String> messages =
        e.getBindingResult().getFieldErrors().stream()
            .map(fe -> fe.getDefaultMessage() != null ? fe.getDefaultMessage() : fe.getField() + " буруу байна")
            .toList();
    return body(HttpStatus.BAD_REQUEST, messages);
  }

  @ExceptionHandler(HttpMessageNotReadableException.class)
  public ResponseEntity<Map<String, Object>> unreadable(HttpMessageNotReadableException e) {
    if (e.getCause() instanceof UnrecognizedPropertyException u) {
      return body(HttpStatus.BAD_REQUEST, List.of("property " + u.getPropertyName() + " should not exist"));
    }
    return body(HttpStatus.BAD_REQUEST, "Хүсэлтийн өгөгдөл буруу байна.");
  }

  @ExceptionHandler(MethodArgumentTypeMismatchException.class)
  public ResponseEntity<Map<String, Object>> typeMismatch(MethodArgumentTypeMismatchException e) {
    return body(HttpStatus.BAD_REQUEST, "Validation failed (uuid is expected)");
  }

  @ExceptionHandler(EmptyResultDataAccessException.class)
  public ResponseEntity<Map<String, Object>> notFound(EmptyResultDataAccessException e) {
    return body(HttpStatus.NOT_FOUND, "Олдсонгүй");
  }

  @ExceptionHandler(NoResourceFoundException.class)
  public ResponseEntity<Map<String, Object>> noRoute(NoResourceFoundException e) {
    return body(HttpStatus.NOT_FOUND, "Cannot " + e.getHttpMethod() + " /" + e.getResourcePath());
  }

  @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
  public ResponseEntity<Map<String, Object>> method(HttpRequestMethodNotSupportedException e) {
    return body(HttpStatus.NOT_FOUND, "Cannot " + e.getMethod());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<Map<String, Object>> unexpected(Exception e) {
    log.error("Unhandled error", e);
    return body(HttpStatus.INTERNAL_SERVER_ERROR, "Internal server error");
  }

  private static ResponseEntity<Map<String, Object>> body(HttpStatus status, Object message) {
    Map<String, Object> b = new LinkedHashMap<>();
    b.put("statusCode", status.value());
    b.put("message", message);
    b.put("error", status.getReasonPhrase());
    return ResponseEntity.status(status).body(b);
  }
}
