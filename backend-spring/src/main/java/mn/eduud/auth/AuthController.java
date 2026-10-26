package mn.eduud.auth;

import jakarta.validation.Valid;
import java.util.Map;
import mn.eduud.auth.AuthDtos.LoginDto;
import mn.eduud.auth.AuthDtos.RefreshDto;
import mn.eduud.auth.AuthDtos.RegisterDto;
import mn.eduud.auth.AuthDtos.RequestOtpDto;
import mn.eduud.auth.AuthDtos.ResetPasswordDto;
import mn.eduud.auth.AuthDtos.VerifyOtpDto;
import mn.eduud.common.auth.AuthAnnotations.Public;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Public
@RestController
@RequestMapping("/auth")
public class AuthController {
  private final AuthService auth;

  public AuthController(AuthService auth) {
    this.auth = auth;
  }

  @PostMapping("/otp/request")
  public Map<String, Object> requestOtp(@Valid @RequestBody RequestOtpDto dto) {
    return auth.requestOtp(dto.phone(), dto.purpose());
  }

  @PostMapping("/otp/verify")
  public Map<String, Object> verifyOtp(@Valid @RequestBody VerifyOtpDto dto) {
    return auth.verifyOtp(dto.phone(), dto.purpose(), dto.code());
  }

  @PostMapping("/register")
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> register(@Valid @RequestBody RegisterDto dto) {
    return auth.register(dto.ticket(), dto.name(), dto.password());
  }

  @PostMapping("/login")
  public Map<String, Object> login(@Valid @RequestBody LoginDto dto) {
    return auth.login(dto.phone(), dto.password());
  }

  @PostMapping("/refresh")
  public Map<String, Object> refresh(@Valid @RequestBody RefreshDto dto) {
    return auth.refresh(dto.refreshToken());
  }

  @PostMapping("/logout")
  public Map<String, Object> logout(@Valid @RequestBody RefreshDto dto) {
    return auth.logout(dto.refreshToken());
  }

  @PostMapping("/password/reset")
  public Map<String, Object> resetPassword(@Valid @RequestBody ResetPasswordDto dto) {
    return auth.resetPassword(dto.ticket(), dto.newPassword());
  }
}
