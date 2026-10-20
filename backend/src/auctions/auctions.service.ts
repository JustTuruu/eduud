import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { AuctionStatus, OrderStatus, Prisma, TokenTxType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { JobsService } from '../jobs/jobs.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import {
  AuctionSnapshot,
  BID_REJECTION_MESSAGES,
  computeNewEndsAt,
  validateBid,
} from './auction.logic';

const Q_START = 'auction-start';
const Q_FINALIZE = 'auction-finalize';
const Q_ORDER_EXPIRE = 'order-expire';

@Injectable()
export class AuctionsService implements OnModuleInit {
  private readonly logger = new Logger(AuctionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jobs: JobsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  async onModuleInit() {
    await this.jobs.work<{ auctionId: string }>(Q_START, (d) => this.handleStart(d.auctionId));
    await this.jobs.work<{ auctionId: string }>(Q_FINALIZE, (d) => this.handleFinalize(d.auctionId));
    await this.jobs.work<{ orderId: string }>(Q_ORDER_EXPIRE, (d) => this.handleOrderExpire(d.orderId));
    await this.recoverSchedules();
  }

  /** Restart-ын дараа live/scheduled auction-уудын job-ыг дахин баталгаажуулна (давхардал хоргүй). */
  private async recoverSchedules() {
    try {
      const live = await this.prisma.auction.findMany({
        where: { status: AuctionStatus.live },
        select: { id: true, endsAt: true },
      });
      for (const a of live) await this.jobs.sendAt(Q_FINALIZE, { auctionId: a.id }, a.endsAt);
      const scheduled = await this.prisma.auction.findMany({
        where: { status: AuctionStatus.scheduled },
        select: { id: true, startsAt: true },
      });
      for (const a of scheduled) await this.jobs.sendAt(Q_START, { auctionId: a.id }, a.startsAt);
      if (live.length + scheduled.length > 0) {
        this.logger.log(`Recovered ${live.length} live + ${scheduled.length} scheduled auction jobs`);
      }
    } catch (e: any) {
      this.logger.warn(`Recovery sweep алдаа (DB бэлэн биш байж магадгүй): ${e.message}`);
    }
  }

  // ---------- Public queries ----------

  async list(status?: 'live' | 'scheduled' | 'ended') {
    const where: Prisma.AuctionWhereInput =
      status === 'ended'
        ? { status: { in: [AuctionStatus.ended, AuctionStatus.settled] } }
        : status
          ? { status: status as AuctionStatus }
          : { status: { in: [AuctionStatus.live, AuctionStatus.scheduled] } };

    return this.prisma.auction.findMany({
      where,
      orderBy: status === 'ended' ? { endsAt: 'desc' } : { endsAt: 'asc' },
      take: 100,
      select: {
        id: true,
        title: true,
        images: true,
        currentPrice: true,
        bidCount: true,
        startsAt: true,
        endsAt: true,
        status: true,
        lastBidder: { select: { id: true, name: true, avatarUrl: true } },
      },
    });
  }

  async detail(id: string) {
    const auction = await this.prisma.auction.findFirst({
      where: { id, status: { not: AuctionStatus.draft } },
      include: {
        lastBidder: { select: { id: true, name: true, avatarUrl: true } },
        bids: {
          orderBy: { createdAt: 'desc' },
          take: 20,
          select: {
            id: true,
            price: true,
            createdAt: true,
            user: { select: { id: true, name: true, avatarUrl: true } },
          },
        },
      },
    });
    if (!auction) throw new NotFoundException('Дуудлага худалдаа олдсонгүй');
    return { ...auction, serverTime: Date.now() };
  }

  // ---------- Bid (атомик гол хэсэг) ----------

  async placeBid(auctionId: string, userId: string) {
    const result = await this.prisma.$transaction(
      async (tx) => {
        // Auction мөрийг түгжинэ — зэрэгцээ bid-үүд дараалалд орно
        const rows = await tx.$queryRaw<any[]>`
          SELECT id, status, starts_at, ends_at, current_price, increment,
                 soft_close_sec, extend_sec, hard_close_at, last_bidder_id, bid_count
          FROM auctions WHERE id = ${auctionId} FOR UPDATE`;
        if (rows.length === 0) throw new NotFoundException('Дуудлага худалдаа олдсонгүй');
        const row = rows[0];
        const snapshot: AuctionSnapshot = {
          status: row.status,
          startsAt: row.starts_at,
          endsAt: row.ends_at,
          currentPrice: row.current_price,
          increment: row.increment,
          softCloseSec: row.soft_close_sec,
          extendSec: row.extend_sec,
          hardCloseAt: row.hard_close_at,
          lastBidderId: row.last_bidder_id,
        };

        const now = new Date();
        const rejection = validateBid(snapshot, userId, now);
        if (rejection) throw new BadRequestException(BID_REJECTION_MESSAGES[rejection]);

        // 1 token хасна — үлдэгдэл хүрэлцэхгүй бол count=0
        const debit = await tx.wallet.updateMany({
          where: { userId, balance: { gte: 1 } },
          data: { balance: { decrement: 1 } },
        });
        if (debit.count === 0) {
          throw new BadRequestException('Token хүрэлцэхгүй байна. Дансаа цэнэглэнэ үү.');
        }

        const newPrice = snapshot.currentPrice + snapshot.increment;
        const newEndsAt = computeNewEndsAt(snapshot, now);

        const bid = await tx.bid.create({
          data: { auctionId, userId, price: newPrice },
        });
        await tx.auction.update({
          where: { id: auctionId },
          data: {
            currentPrice: newPrice,
            endsAt: newEndsAt,
            lastBidderId: userId,
            bidCount: { increment: 1 },
          },
        });
        await tx.tokenTransaction.create({
          data: {
            userId,
            amount: -1,
            type: TokenTxType.bid,
            refId: bid.id,
            note: `Санал: ${newPrice}₮`,
          },
        });
        const wallet = await tx.wallet.findUniqueOrThrow({ where: { userId } });
        const bidder = await tx.user.findUniqueOrThrow({
          where: { id: userId },
          select: { id: true, name: true, avatarUrl: true },
        });

        return {
          bid,
          newPrice,
          newEndsAt,
          extended: newEndsAt.getTime() !== snapshot.endsAt.getTime(),
          previousBidderId: snapshot.lastBidderId,
          newBalance: wallet.balance,
          bidCount: row.bid_count + 1,
          bidder,
        };
      },
      { timeout: 10000 },
    );

    // Broadcast (transaction-ы гадна)
    this.realtime.emitToAuction(auctionId, 'bid_placed', {
      auctionId,
      price: result.newPrice,
      endsAt: result.newEndsAt.toISOString(),
      bidCount: result.bidCount,
      bidder: result.bidder,
    });
    if (result.extended) {
      this.realtime.emitToAuction(auctionId, 'auction_extended', {
        auctionId,
        endsAt: result.newEndsAt.toISOString(),
      });
    }
    this.realtime.emitToUser(userId, 'wallet_updated', { balance: result.newBalance });
    if (result.previousBidderId) {
      this.realtime.emitToUser(result.previousBidderId, 'outbid', {
        auctionId,
        price: result.newPrice,
      });
    }

    // Finalize job-ыг шинэ endsAt дээр дахин товлоно
    await this.jobs.sendAt(Q_FINALIZE, { auctionId }, result.newEndsAt);

    return {
      ok: true,
      price: result.newPrice,
      endsAt: result.newEndsAt.toISOString(),
      balance: result.newBalance,
    };
  }

  // ---------- Lifecycle (админ + job) ----------

  /** Админ draft auction-ыг нийтэлнэ: scheduled эсвэл шууд live. */
  async publish(auctionId: string) {
    const auction = await this.prisma.auction.findUniqueOrThrow({ where: { id: auctionId } });
    if (auction.status !== AuctionStatus.draft) {
      throw new BadRequestException('Зөвхөн draft auction нийтлэх боломжтой.');
    }
    const now = new Date();
    if (auction.startsAt <= now) {
      await this.prisma.auction.update({
        where: { id: auctionId },
        data: { status: AuctionStatus.live },
      });
      await this.jobs.sendAt(Q_FINALIZE, { auctionId }, auction.endsAt);
      this.realtime.emitToAuction(auctionId, 'auction_started', { auctionId });
    } else {
      await this.prisma.auction.update({
        where: { id: auctionId },
        data: { status: AuctionStatus.scheduled },
      });
      await this.jobs.sendAt(Q_START, { auctionId }, auction.startsAt);
    }
    return { ok: true };
  }

  async cancel(auctionId: string) {
    const auction = await this.prisma.auction.findUniqueOrThrow({ where: { id: auctionId } });
    const cancellable: AuctionStatus[] = [AuctionStatus.draft, AuctionStatus.scheduled, AuctionStatus.live];
    if (!cancellable.includes(auction.status)) {
      throw new BadRequestException('Энэ төлөвт цуцлах боломжгүй.');
    }
    await this.prisma.auction.update({
      where: { id: auctionId },
      data: { status: AuctionStatus.cancelled },
    });
    this.realtime.emitToAuction(auctionId, 'auction_cancelled', { auctionId });
    return { ok: true };
  }

  private async handleStart(auctionId: string) {
    const updated = await this.prisma.auction.updateMany({
      where: { id: auctionId, status: AuctionStatus.scheduled },
      data: { status: AuctionStatus.live },
    });
    if (updated.count === 0) return;
    const auction = await this.prisma.auction.findUniqueOrThrow({ where: { id: auctionId } });
    await this.jobs.sendAt(Q_FINALIZE, { auctionId }, auction.endsAt);
    this.realtime.emitToAuction(auctionId, 'auction_started', { auctionId });
    this.logger.log(`Auction ${auctionId} started`);
  }

  private async handleFinalize(auctionId: string) {
    const outcome = await this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<any[]>`
        SELECT id, status, ends_at, current_price, last_bidder_id
        FROM auctions WHERE id = ${auctionId} FOR UPDATE`;
      if (rows.length === 0) return null;
      const row = rows[0];
      if (row.status !== 'live') return null;

      // Soft close-оор сунгагдсан бол дахин товлоод гарна
      if (new Date(row.ends_at) > new Date()) {
        return { reschedule: new Date(row.ends_at) };
      }

      await tx.auction.update({
        where: { id: auctionId },
        data: { status: AuctionStatus.ended },
      });

      if (!row.last_bidder_id) return { winner: null };

      const deadlineHours = Number(process.env.ORDER_PAY_DEADLINE_HOURS ?? 24);
      const order = await tx.order.create({
        data: {
          auctionId,
          winnerId: row.last_bidder_id,
          finalPrice: row.current_price,
          payDeadline: new Date(Date.now() + deadlineHours * 3600 * 1000),
          status: OrderStatus.pending,
        },
      });
      return { winner: row.last_bidder_id, finalPrice: row.current_price, order };
    });

    if (!outcome) return;
    if ('reschedule' in outcome && outcome.reschedule) {
      await this.jobs.sendAt(Q_FINALIZE, { auctionId }, outcome.reschedule);
      return;
    }
    if ('winner' in outcome) {
      this.realtime.emitToAuction(auctionId, 'auction_ended', {
        auctionId,
        winnerId: outcome.winner,
        finalPrice: 'finalPrice' in outcome ? outcome.finalPrice : null,
      });
      if (outcome.winner && outcome.order) {
        this.realtime.emitToUser(outcome.winner, 'auction_won', {
          auctionId,
          orderId: outcome.order.id,
          finalPrice: outcome.finalPrice,
          payDeadline: outcome.order.payDeadline.toISOString(),
        });
        await this.jobs.sendAt(Q_ORDER_EXPIRE, { orderId: outcome.order.id }, outcome.order.payDeadline);
      }
      this.logger.log(`Auction ${auctionId} ended, winner=${outcome.winner ?? 'байхгүй'}`);
    }
  }

  private async handleOrderExpire(orderId: string) {
    const updated = await this.prisma.order.updateMany({
      where: { id: orderId, status: OrderStatus.pending },
      data: { status: OrderStatus.expired },
    });
    if (updated.count > 0) this.logger.log(`Order ${orderId} expired (төлбөр хийгдээгүй)`);
  }
}
