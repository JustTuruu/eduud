import { IsEnum, IsNotEmpty, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { OtpPurpose } from '@prisma/client';

const PHONE_REGEX = /^[6-9]\d{7}$/; // Монгол гар утасны дугаар: 8 орон

export class RequestOtpDto {
  @Matches(PHONE_REGEX, { message: 'Утасны дугаар буруу байна (8 орон)' })
  phone: string;

  @IsEnum(OtpPurpose)
  purpose: OtpPurpose;
}

export class VerifyOtpDto extends RequestOtpDto {
  @IsString()
  @MinLength(6)
  @MaxLength(6)
  code: string;
}

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  ticket: string;

  @IsString()
  @MinLength(2)
  @MaxLength(30)
  name: string;

  @IsString()
  @MinLength(8, { message: 'Нууц үг хамгийн багадаа 8 тэмдэгт' })
  @MaxLength(72)
  password: string;
}

export class LoginDto {
  @Matches(PHONE_REGEX, { message: 'Утасны дугаар буруу байна (8 орон)' })
  phone: string;

  @IsString()
  @IsNotEmpty()
  password: string;
}

export class RefreshDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class ResetPasswordDto {
  @IsString()
  @IsNotEmpty()
  ticket: string;

  @IsString()
  @MinLength(8, { message: 'Нууц үг хамгийн багадаа 8 тэмдэгт' })
  @MaxLength(72)
  newPassword: string;
}
