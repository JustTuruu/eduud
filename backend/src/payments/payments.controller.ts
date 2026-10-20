import {
  Body,
  Controller,
  ForbiddenException,
  Headers,
  HttpCode,
  Param,
  Post,
  Req,
} from '@nestjs/common';
import { Public } from '../common/decorators';
import { PaymentsService } from './payments.service';
import { WireService } from './wire.service';

@Controller('payments')
export class PaymentsController {
  constructor(
    private readonly payments: PaymentsService,
    private readonly wire: WireService,
  ) {}

  /**
   * wire.mn webhook. Body-г raw string-ээр signature шалгана.
   * TODO(wire.mn): payload-ын бүтцийг албан ёсны бичиг баримттай тулгах.
   */
  @Public()
  @Post('wire/webhook')
  @HttpCode(200)
  async webhook(
    @Req() req: any,
    @Body() body: any,
    @Headers('x-wire-signature') signature?: string,
  ) {
    const raw = req.rawBody?.toString?.() ?? JSON.stringify(body);
    this.wire.verifyWebhookSignature(raw, signature);
    const invoiceId = body.invoice_id ?? body.invoiceId ?? body.id;
    const status = (body.status ?? '').toString().toUpperCase();
    if (invoiceId && (status === 'PAID' || status === 'SUCCESS')) {
      await this.payments.settleByInvoiceId(invoiceId, body);
    }
    return { ok: true };
  }

  /** Зөвхөн WIRE_MODE=test үед: төлбөрийг гараар "төлөгдсөн" болгож симуляци хийнэ. */
  @Public()
  @Post('wire/test-pay/:invoiceId')
  @HttpCode(200)
  async testPay(@Param('invoiceId') invoiceId: string) {
    if ((process.env.WIRE_MODE ?? 'test') === 'live') {
      throw new ForbiddenException('Test горимд л ажиллана');
    }
    await this.payments.settleByInvoiceId(invoiceId, { simulated: true });
    return { ok: true };
  }
}
