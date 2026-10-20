import { Controller, Get, Module, NotFoundException, Param } from '@nestjs/common';
import { Public } from '../common/decorators';
import { PrismaService } from '../prisma/prisma.service';

@Public()
@Controller('content')
class ContentController {
  constructor(private readonly prisma: PrismaService) {}

  /** terms | privacy | faq */
  @Get(':key')
  async get(@Param('key') key: string) {
    const content = await this.prisma.appContent.findUnique({ where: { key } });
    if (!content) throw new NotFoundException('Контент олдсонгүй');
    return content;
  }
}

/**
 * Апп ажиллах орчны төлөв. Флаг тус бүр нь ямар нэг нууц утга задруулахгүй —
 * зөвхөн "энэ орчинд тест хийж болно" гэдгийг апп-д мэдэгдэнэ.
 */
@Public()
@Controller('config')
class AppConfigController {
  @Get()
  get() {
    return {
      /** OTP мессеж жинхэнээсээ илгээгддэггүй — код нь хариунд ирнэ. */
      otpTestMode: process.env.OTP_PROVIDER !== 'verifymn',
      /** Төлбөрийг гараар "төлөгдсөн" болгож симуляци хийж болно. */
      paymentTestMode: (process.env.WIRE_MODE ?? 'test') !== 'live',
    };
  }
}

@Module({
  controllers: [ContentController, AppConfigController],
})
export class ContentModule {}
