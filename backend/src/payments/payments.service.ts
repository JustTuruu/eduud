import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PaymentStatus, TokenTxType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { WireService } from './wire.service';

/**
 * Төлбөр батлагдсаны дараах нэгдсэн settle логик.
 * Idempotent: `updateMany({status: pending} -> paid)` guard-аар нэг л удаа хэрэгжинэ —
 * wire.mn webhook давхар ирсэн ч token давхар нэмэгдэхгүй.
 */
@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly wire: WireService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async settleByInvoiceId(wireInvoiceId: string, rawWebhook?: object) {
    const payment = await this.prisma.payment.findUnique({
      where: { wireInvoiceId },
      include: { package: true },
    });
    if (!payment) throw new NotFoundException('Invoice олдсонгүй');
    return this.settle(payment.id, rawWebhook);
  }

  async settle(paymentId: string, rawWebhook?: object) {
    const result = await this.prisma.$transaction(async (tx) => {
      // Idempotency guard: pending -> paid шилжилт зөвхөн нэг удаа амжина
      const updated = await tx.payment.updateMany({
        where: { id: paymentId, status: PaymentStatus.pending },
        data: {
          status: PaymentStatus.paid,
          paidAt: new Date(),
          ...(rawWebhook ? { rawWebhook: rawWebhook as any } : {}),
        },
      });
      if (updated.count === 0) return null; // аль хэдийн боловсруулсан

      const payment = await tx.payment.findUniqueOrThrow({
        where: { id: paymentId },
        include: { package: true },
      });

      if (payment.kind === 'topup') {
        const tokens = payment.package?.tokens;
        if (!tokens) throw new Error(`Payment ${paymentId}: package алга`);
        await tx.wallet.update({
          where: { userId: payment.userId },
          data: { balance: { increment: tokens } },
        });
        await tx.tokenTransaction.create({
          data: {
            userId: payment.userId,
            amount: tokens,
            type: TokenTxType.purchase,
            refId: payment.id,
            note: `${tokens} token цэнэглэлт`,
          },
        });
        const wallet = await tx.wallet.findUniqueOrThrow({ where: { userId: payment.userId } });
        return { payment, newBalance: wallet.balance };
      }

      if (payment.kind === 'order' && payment.orderId) {
        await tx.order.update({
          where: { id: payment.orderId },
          data: { status: 'paid' },
        });
        return { payment, newBalance: null };
      }

      return { payment, newBalance: null };
    });

    if (result) {
      const { payment, newBalance } = result;
      if (newBalance !== null) {
        this.realtime.emitToUser(payment.userId, 'wallet_updated', { balance: newBalance });
      } else {
        this.realtime.emitToUser(payment.userId, 'order_paid', { orderId: payment.orderId });
      }
      this.logger.log(`Payment ${paymentId} settled (${payment.kind})`);
    }
    return { ok: true };
  }

  /** Fallback: хэрэглэгч "төлбөр шалгах" дарахад wire.mn-ээс лавлаж settle хийнэ. */
  async checkAndSettle(userId: string, paymentId: string) {
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, userId },
    });
    if (!payment) throw new NotFoundException('Төлбөр олдсонгүй');
    if (payment.status === PaymentStatus.paid) return { status: 'paid' };
    if (!payment.wireInvoiceId) throw new BadRequestException('Invoice үүсээгүй');

    const status = await this.wire.inquiry(payment.wireInvoiceId);
    if (status === 'paid') {
      await this.settle(payment.id);
      return { status: 'paid' };
    }
    return { status };
  }
}
