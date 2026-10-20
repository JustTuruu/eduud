import { BadRequestException, Body, Controller, ForbiddenException, Post } from '@nestjs/common';
import { IsIn, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../common/decorators';
import { R2Service } from './r2.service';

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

class PresignDto {
  @IsIn(['avatar', 'auction'])
  kind: 'avatar' | 'auction';

  @IsString()
  contentType: string;
}

@Controller('media')
export class MediaController {
  constructor(private readonly r2: R2Service) {}

  @Post('presign')
  presign(@CurrentUser() user: AuthUser, @Body() dto: PresignDto) {
    if (!ALLOWED_TYPES.includes(dto.contentType)) {
      throw new BadRequestException('Зөвхөн JPEG/PNG/WebP зураг зөвшөөрнө.');
    }
    if (dto.kind === 'auction' && user.role !== 'admin') {
      throw new ForbiddenException('Хандах эрхгүй');
    }
    return this.r2.presignUpload(dto.kind === 'avatar' ? 'avatars' : 'auctions', dto.contentType);
  }
}
