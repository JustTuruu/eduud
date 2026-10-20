import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { OrderStatus, PaymentKind, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { WireService } from '../payments/wire.service';

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly wire: WireService,
  ) {}

  async myOrders(userId: string) {
    return this.prisma.order.findMany({
      where: { winnerId: userId },
      orderBy: { createdAt: 'desc' },
      include: {
        auction: { select: { id: true, title: true, images: true } },
      },
    });
  }

  /** Ялсан барааны эцсийн үнийг төлөх wire.mn invoice үүсгэнэ. */
  async pay(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, winnerId: userId },
      include: { auction: true, payment: true },
    });
    if (!order) throw new NotFoundException('Захиалга олдсонгүй');
    if (order.status === OrderStatus.paid) throw new BadRequestException('Төлбөр аль хэдийн хийгдсэн.');
    if (order.status !== OrderStatus.pending) {
      throw new BadRequestException('Захиалгын хугацаа дууссан.');
    }

    // Өмнө үүсгэсэн pending invoice байвал түүнийгээ буцаана
    if (order.payment && order.payment.status === PaymentStatus.pending && order.payment.wireInvoiceId) {
      return {
        paymentId: order.payment.id,
        invoiceId: order.payment.wireInvoiceId,
        amountMnt: order.finalPrice,
      };
    }

    const payment = await this.prisma.payment.create({
      data: {
        userId,
        kind: PaymentKind.order,
        orderId: order.id,
        amountMnt: order.finalPrice,
        status: PaymentStatus.pending,
      },
    });
    const invoice = await this.wire.createInvoice({
      amountMnt: order.finalPrice,
      description: `E-Duud ялалт: ${order.auction.title}`,
      referenceId: payment.id,
    });
    await this.prisma.payment.update({
      where: { id: payment.id },
      data: { wireInvoiceId: invoice.invoiceId },
    });

    return {
      paymentId: payment.id,
      invoiceId: invoice.invoiceId,
      amountMnt: order.finalPrice,
      qrText: invoice.qrText,
      qrImageUrl: invoice.qrImageUrl,
      deeplink: invoice.deeplink,
    };
  }
}
