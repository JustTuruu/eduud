import { Body, Controller, Module, Post } from '@nestjs/common';
import { IsNotEmpty, IsString } from 'class-validator';
import { AuthUser, CurrentUser } from '../common/decorators';
import { PrismaService } from '../prisma/prisma.service';

class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  fcmToken: string;
}

@Controller('devices')
class DevicesController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async register(@CurrentUser() user: AuthUser, @Body() dto: RegisterDeviceDto) {
    await this.prisma.device.upsert({
      where: { fcmToken: dto.fcmToken },
      create: { userId: user.id, fcmToken: dto.fcmToken },
      update: { userId: user.id },
    });
    return { ok: true };
  }
}

@Module({
  controllers: [DevicesController],
})
export class DevicesModule {}
