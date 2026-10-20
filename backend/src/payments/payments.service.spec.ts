import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PaymentsService } from './payments.service';

/**
 * Webhook idempotency: нэг invoice-ийн webhook 2 удаа ирэхэд token
 * зөвхөн нэг удаа нэмэгдэхийг шалгана.
 */
describe('PaymentsService.settle (idempotency)', () => {
  let paymentStatus = 'pending';
  let creditCount = 0;

  const payment = {
    id: 'pay-1',
    userId: 'u1',
    kind: 'topup',
    orderId: null,
    package: { tokens: 30 },
  };

  const tx = {
    payment: {
      // pending -> paid guard-ын симуляци
      updateMany: vi.fn(async ({ where }: any) => {
        if (where.status === 'pending' && paymentStatus === 'pending') {
          paymentStatus = 'paid';
          return { count: 1 };
        }
        return { count: 0 };
      }),
      findUniqueOrThrow: vi.fn(async () => payment),
    },
    wallet: {
      update: vi.fn(async () => {
        creditCount++;
        return {};
      }),
      findUniqueOrThrow: vi.fn(async () => ({ balance: 30 * creditCount })),
    },
    tokenTransaction: { create: vi.fn(async () => ({})) },
    order: { update: vi.fn(async () => ({})) },
  };

  const prisma = {
    $transaction: (cb: (t: typeof tx) => Promise<unknown>) => cb(tx),
    payment: {
      findUnique: vi.fn(async () => payment),
    },
  };

  const realtime = { emitToUser: vi.fn() };
  const wire = { inquiry: vi.fn() };

  let service: PaymentsService;

  beforeEach(() => {
    paymentStatus = 'pending';
    creditCount = 0;
    vi.clearAllMocks();
    service = new PaymentsService(prisma as any, wire as any, realtime as any);
  });

  it('эхний settle дээр token нэмж wallet_updated илгээнэ', async () => {
    await service.settle('pay-1');
    expect(creditCount).toBe(1);
    expect(realtime.emitToUser).toHaveBeenCalledWith('u1', 'wallet_updated', { balance: 30 });
  });

  it('давхар webhook дээр token ДАХИН нэмэгдэхгүй', async () => {
    await service.settle('pay-1');
    await service.settle('pay-1');
    await service.settle('pay-1');
    expect(creditCount).toBe(1);
    expect(realtime.emitToUser).toHaveBeenCalledTimes(1);
  });

  it('settleByInvoiceId нь invoice-оор олж settle хийнэ', async () => {
    const prismaWithInvoice = {
      ...prisma,
      payment: {
        findUnique: vi.fn(async ({ where }: any) =>
          where.wireInvoiceId === 'inv-1' ? payment : null,
        ),
      },
    };
    const s = new PaymentsService(prismaWithInvoice as any, wire as any, realtime as any);
    await s.settleByInvoiceId('inv-1');
    expect(creditCount).toBe(1);
  });

  it('олдохгүй invoice дээр NotFound шиднэ', async () => {
    const prismaEmpty = {
      ...prisma,
      payment: { findUnique: vi.fn(async () => null) },
    };
    const s = new PaymentsService(prismaEmpty as any, wire as any, realtime as any);
    await expect(s.settleByInvoiceId('inv-x')).rejects.toThrow();
  });
});
