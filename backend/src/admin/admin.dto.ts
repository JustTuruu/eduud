import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDate,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateAuctionDto {
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  title: string;

  @IsString()
  @MaxLength(5000)
  description: string;

  @IsArray()
  @ArrayMaxSize(10)
  @IsUrl({ require_tld: false }, { each: true })
  images: string[];

  /** Эхлэх үнэ (₮) */
  @IsInt()
  @Min(0)
  startPrice: number;

  /** Санал бүрийн үнийн өсөлт (₮) */
  @IsInt()
  @Min(1)
  @Max(1000000)
  increment: number;

  /** Soft close цонх (сек) — дуусахад үүнээс бага үлдэхэд bid ирвэл сунгана */
  @IsInt()
  @Min(0)
  @Max(3600)
  softCloseSec: number;

  /** Сунгалт (сек) */
  @IsInt()
  @Min(0)
  @Max(3600)
  extendSec: number;

  @IsOptional()
  @IsDate()
  @Type(() => Date)
  hardCloseAt?: Date;

  @IsDate()
  @Type(() => Date)
  startsAt: Date;

  @IsDate()
  @Type(() => Date)
  endsAt: Date;
}

export class UpdateAuctionDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsUrl({ require_tld: false }, { each: true })
  images?: string[];

  @IsOptional()
  @IsInt()
  @Min(0)
  startPrice?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(1000000)
  increment?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(3600)
  softCloseSec?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(3600)
  extendSec?: number;

  @IsOptional()
  @IsDate()
  @Type(() => Date)
  hardCloseAt?: Date;

  @IsOptional()
  @IsDate()
  @Type(() => Date)
  startsAt?: Date;

  @IsOptional()
  @IsDate()
  @Type(() => Date)
  endsAt?: Date;
}

export class UpsertPackageDto {
  @IsInt()
  @Min(1)
  tokens: number;

  @IsInt()
  @Min(100)
  priceMnt: number;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}

export class UpdateContentDto {
  @IsString()
  @MaxLength(200)
  title: string;

  @IsString()
  body: string;
}

export class AdjustTokensDto {
  @IsInt()
  amount: number;

  @IsString()
  @MaxLength(200)
  note: string;
}
