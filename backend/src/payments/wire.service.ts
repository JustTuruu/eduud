import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { createHmac, randomUUID, timingSafeEqual } from 'crypto';

export interface WireInvoice {
  invoiceId: string;
  qrText: string;
  qrImageUrl?: string;
  deeplink?: string;
}

/**
 * wire.mn төлбөрийн gateway adapter.
 * WIRE_MODE=test үед invoice-г локал симуляци хийнэ (хөгжүүлэлтэд DB/түрийвч
 * шаардлагагүй), live үед wire.mn REST API дуудна.
 *
 * TODO(wire.mn): merchant бүртгэл баталгаажсаны дараа доорх endpoint/талбаруудыг
 * албан ёсны API бичиг баримттай тулгаж тохируулах.
 */
@Injectable()
export class WireService {
  private readonly logger = new Logger(WireService.name);
  private get isTest() {
    return (process.env.WIRE_MODE ?? 'test') !== 'live';
  }

  async createInvoice(params: {
    amountMnt: number;
    description: string;
    referenceId: string;
  }): Promise<WireInvoice> {
    if (this.isTest) {
      const invoiceId = `test_${randomUUID()}`;
      this.logger.warn(`[WIRE TEST] invoice ${invoiceId} — ${params.amountMnt}₮ (${params.description})`);
      return {
        invoiceId,
        qrText: `WIRE-TEST:${invoiceId}:${params.amountMnt}`,
        deeplink: `eduud://payment/test/${invoiceId}`,
      };
    }

    const res = await fetch(`${process.env.WIRE_API_URL}/v1/invoices`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.WIRE_API_KEY}`,
      },
      body: JSON.stringify({
        amount: params.amountMnt,
        currency: 'MNT',
        description: params.description,
        reference_id: params.referenceId,
      }),
    });
    if (!res.ok) {
      throw new Error(`wire.mn invoice үүсгэхэд алдаа: ${res.status} ${await res.text()}`);
    }
    const data = (await res.json()) as any;
    return {
      invoiceId: data.id,
      qrText: data.qr_text,
      qrImageUrl: data.qr_image,
      deeplink: data.deeplink,
    };
  }

  /** Invoice-ийн төлөвийг wire.mn-ээс лавлана (webhook алдсан үеийн fallback). */
  async inquiry(invoiceId: string): Promise<'paid' | 'pending' | 'failed'> {
    if (this.isTest) {
      // Test горимд: /payments/wire/test-pay endpoint-оор "төлсөн" болгодог тул
      // inquiry нь үргэлж pending буцаана.
      return 'pending';
    }
    const res = await fetch(`${process.env.WIRE_API_URL}/v1/invoices/${invoiceId}`, {
      headers: { Authorization: `Bearer ${process.env.WIRE_API_KEY}` },
    });
    if (!res.ok) throw new Error(`wire.mn inquiry алдаа: ${res.status}`);
    const data = (await res.json()) as any;
    return data.status === 'PAID' ? 'paid' : data.status === 'FAILED' ? 'failed' : 'pending';
  }

  /** Webhook-ийн HMAC-SHA256 гарын үсгийг шалгана. */
  verifyWebhookSignature(rawBody: string, signature: string | undefined): void {
    if (this.isTest) return;
    if (!signature) throw new UnauthorizedException('Signature алга');
    const expected = createHmac('sha256', process.env.WIRE_WEBHOOK_SECRET ?? '')
      .update(rawBody)
      .digest('hex');
    const a = Buffer.from(expected);
    const b = Buffer.from(signature);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      throw new UnauthorizedException('Signature буруу');
    }
  }
}
