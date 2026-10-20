import {
  Body,
  Controller,
  Get,
  HttpCode,
  Patch,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import * as argon2 from 'argon2';
import { AuthUser, CurrentUser } from '../common/decorators';
import { PrismaService } from '../prisma/prisma.service';

class UpdateMeDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(30)
  name?: string;

  /**
   * Хоёр хэлбэрийг зөвшөөрнө:
   *  - `https://...` — R2-д байршуулсан жинхэнэ зураг
   *  - `preset:<id>` — апп дотор бэлэн градиент аватар (сервер лүү зураг ачаалахгүй)
   */
  @IsOptional()
  @Matches(/^(https?:\/\/\S{3,500}|preset:[a-z0-9-]{1,32})$/, {
    message: 'Аватарын утга буруу байна.',
  })
  avatarUrl?: string;
}

class ChangePasswordDto {
  @IsString()
  currentPassword: string;

  @IsString()
  @MinLength(8, { message: 'Нууц үг хамгийн багадаа 8 тэмдэгт' })
  @MaxLength(72)
  newPassword: string;
}

@Controller('me')
export class UsersController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async me(@CurrentUser() user: AuthUser) {
    const u = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
      include: { wallet: true },
    });
    return {
      id: u.id,
      phone: u.phone,
      name: u.name,
      avatarUrl: u.avatarUrl,
      role: u.role,
      balance: u.wallet?.balance ?? 0,
    };
  }

  @Patch()
  async update(@CurrentUser() user: AuthUser, @Body() dto: UpdateMeDto) {
    const u = await this.prisma.user.update({
      where: { id: user.id },
      data: { name: dto.name, avatarUrl: dto.avatarUrl },
    });
    return { id: u.id, name: u.name, avatarUrl: u.avatarUrl };
  }

  @Post('password')
  @HttpCode(200)
  async changePassword(@CurrentUser() user: AuthUser, @Body() dto: ChangePasswordDto) {
    const u = await this.prisma.user.findUniqueOrThrow({ where: { id: user.id } });
    if (!(await argon2.verify(u.passwordHash, dto.currentPassword))) {
      throw new UnauthorizedException('Одоогийн нууц үг буруу байна.');
    }
    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: await argon2.hash(dto.newPassword) },
    });
    return { ok: true };
  }
}
