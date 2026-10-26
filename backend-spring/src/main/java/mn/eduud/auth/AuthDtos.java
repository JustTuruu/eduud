package mn.eduud.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public final class AuthDtos {
  private AuthDtos() {}

  /** Монгол гар утасны дугаар: 8 орон. */
  static final String PHONE = "^[6-9]\\d{7}$";
  static final String PHONE_MSG = "Утасны дугаар буруу байна (8 орон)";
  static final String PURPOSE = "^(register|reset)$";
  static final String PWD_MSG = "Нууц үг хамгийн багадаа 8 тэмдэгт";

  public record RequestOtpDto(
      @NotNull @Pattern(regexp = PHONE, message = PHONE_MSG) String phone,
      @NotNull @Pattern(regexp = PURPOSE, message = "purpose must be one of: register, reset") String purpose) {}

  public record VerifyOtpDto(
      @NotNull @Pattern(regexp = PHONE, message = PHONE_MSG) String phone,
      @NotNull @Pattern(regexp = PURPOSE, message = "purpose must be one of: register, reset") String purpose,
      @NotNull @Size(min = 6, max = 6, message = "code must be 6 characters") String code) {}

  public record RegisterDto(
      @NotBlank String ticket,
      @NotNull @Size(min = 2, max = 30) String name,
      @NotNull @Size(min = 8, max = 72, message = PWD_MSG) String password) {}

  public record LoginDto(
      @NotNull @Pattern(regexp = PHONE, message = PHONE_MSG) String phone, @NotBlank String password) {}

  public record RefreshDto(@NotBlank String refreshToken) {}

  public record ResetPasswordDto(
      @NotBlank String ticket, @NotNull @Size(min = 8, max = 72, message = PWD_MSG) String newPassword) {}
}
