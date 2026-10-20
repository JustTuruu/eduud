import { FeedbackCategory, FeedbackStatus, FeedbackType } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateFeedbackDto {
  @IsEnum(FeedbackType, { message: 'Төрлөө сонгоно уу.' })
  type: FeedbackType;

  @IsEnum(FeedbackCategory, { message: 'Ангиллаа сонгоно уу.' })
  category: FeedbackCategory;

  @IsString()
  @MinLength(10, { message: 'Дэлгэрэнгүйг 10-аас доошгүй тэмдэгтээр бичнэ үү.' })
  @MaxLength(2000, { message: 'Дэлгэрэнгүй 2000 тэмдэгтээс хэтэрч болохгүй.' })
  message: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  appVersion?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  platform?: string;
}

export class UpdateFeedbackDto {
  @IsEnum(FeedbackStatus)
  status: FeedbackStatus;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  adminNote?: string;
}
