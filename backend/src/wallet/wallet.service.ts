import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PaymentKind, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { WireService } from '../payments/wire.service';

@Injectable()
export class WalletService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly wire: WireService,
  ) {}

  async balance(userId: string) {
    const wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    return { balance: wallet?.balance ?? 0 };
  }

  async packages() {
    return this.prisma.tokenPackage.findMany({
      where: { active: true },
      orderBy: { sortOrder: 'asc' },
      select: { id: true, tokens: true, priceMnt: true },
    });
  }

  async transactions(userId: string, take = 50) {
    return this.prisma.tokenTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take,
      select: { id: true, amount: true, type: true, note: true, createdAt: true },
    });
  }

  /** Багц сонгож wire.mn invoice үүсгэнэ. */
  async topup(userId: string, packageId: string) {
    const pkg = await this.prisma.tokenPackage.findFirst({
      where: { id: packageId, active: true },
    });
    if (!pkg) throw new NotFoundException('Багц олдсонгүй');

    const payment = await this.prisma.payment.create({
      data: {
        userId,
        kind: PaymentKind.topup,
        packageId: pkg.id,
        amountMnt: pkg.priceMnt,
        status: PaymentStatus.pending,
      },
    });

    let invoice;
    try {
      invoice = await this.wire.createInvoice({
        amountMnt: pkg.priceMnt,
        description: `E-Duud: ${pkg.tokens} token`,
        referenceId: payment.id,
      });
    } catch (e) {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.failed },
      });
      throw new BadRequestException('Төлбөрийн нэхэмжлэх үүсгэж чадсангүй. Дахин оролдоно уу.');
    }

    await this.prisma.payment.update({
      where: { id: payment.id },
      data: { wireInvoiceId: invoice.invoiceId },
    });

    return {
      paymentId: payment.id,
      invoiceId: invoice.invoiceId,
      amountMnt: pkg.priceMnt,
      tokens: pkg.tokens,
      qrText: invoice.qrText,
      qrImageUrl: invoice.qrImageUrl,
      deeplink: invoice.deeplink,
    };
  }
}
