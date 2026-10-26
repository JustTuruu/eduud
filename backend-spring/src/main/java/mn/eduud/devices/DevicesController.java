package mn.eduud.devices;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.Map;
import mn.eduud.common.Ids;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthUser;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/devices")
public class DevicesController {
  private final JdbcClient db;

  public DevicesController(JdbcClient db) {
    this.db = db;
  }

  public record RegisterDeviceDto(@NotBlank String fcmToken) {}

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> register(@CurrentUser AuthUser user, @Valid @RequestBody RegisterDeviceDto dto) {
    db.sql(
            "INSERT INTO devices (id, user_id, fcm_token) VALUES (?, ?, ?)"
                + " ON CONFLICT (fcm_token) DO UPDATE SET user_id = EXCLUDED.user_id")
        .params(Ids.uuid(), user.id(), dto.fcmToken())
        .update();
    return Map.of("ok", true);
  }
}
