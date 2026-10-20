import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { AuctionStatus, TokenTxType, UserStatus } from '@prisma/client';
import { AuthUser, CurrentUser, Roles } from '../common/decorators';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeGateway } from '../realtime/realtime.gateway';
import { AuctionsService } from '../auctions/auctions.service';
import {
  AdjustTokensDto,
  CreateAuctionDto,
  UpdateAuctionDto,
  UpdateContentDto,
  UpsertPackageDto,
} from './admin.dto';

@Roles('admin')
@Controller('admin')
export class AdminController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auctions: AuctionsService,
    private readonly realtime: RealtimeGateway,
  ) {}

  // ---------- Auctions ----------

  @Get('auctions')
  listAuctions(@Query('status') status?: AuctionStatus) {
    return this.prisma.auction.findMany({
      where: status ? { status } : undefined,
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: { lastBidder: { select: { id: true, name: true } }, order: true },
    });
  }

  @Post('auctions')
  createAuction(@CurrentUser() user: AuthUser, @Body() dto: CreateAuctionDto) {
    if (dto.endsAt <= dto.startsAt) {
      throw new BadRequestException('Дуусах хугацаа эхлэхээс хойш байх ёстой.');
    }
    return this.prisma.auction.create({
      data: {
        ...dto,
        currentPrice: dto.startPrice,
        status: AuctionStatus.draft,
        createdById: user.id,
      },
    });
  }

  @Patch('auctions/:id')
  async updateAuction(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateAuctionDto) {
    const auction = await this.prisma.auction.findUniqueOrThrow({ where: { id } });
    if (auction.status !== AuctionStatus.draft) {
      throw new BadRequestException('Зөвхөн draft auction засах боломжтой.');
    }
    return this.prisma.auction.update({
      where: { id },
      data: {
        ...dto,
        ...(dto.startPrice !== undefined ? { currentPrice: dto.startPrice } : {}),
      },
    });
  }

  @Post('auctions/:id/publish')
  @HttpCode(200)
  publish(@Param('id', ParseUUIDPipe) id: string) {
    return this.auctions.publish(id);
  }

  @Post('auctions/:id/cancel')
  @HttpCode(200)
  cancel(@Param('id', ParseUUIDPipe) id: string) {
    return this.auctions.cancel(id);
  }

  // ---------- Users ----------

  @Get('users')
  users(@Query('q') q?: string) {
    return this.prisma.user.findMany({
      where: q ? { OR: [{ phone: { contains: q } }, { name: { contains: q, mode: 'insensitive' } }] } : undefined,
      orderBy: { createdAt: 'desc' },
      take: 100,
      select: {
        id: true,
        phone: true,
        name: true,
        role: true,
        status: true,
        createdAt: true,
        wallet: { select: { balance: true } },
      },
    });
  }

  @Post('users/:id/ban')
  @HttpCode(200)
  async ban(@Param('id', ParseUUIDPipe) id: string) {
    await this.prisma.user.update({ where: { id }, data: { status: UserStatus.banned } });
    return { ok: true };
  }

  @Post('users/:id/unban')
  @HttpCode(200)
  async unban(@Param('id', ParseUUIDPipe) id: string) {
    await this.prisma.user.update({ where: { id }, data: { status: UserStatus.active } });
    return { ok: true };
  }

  /** Гараар token нэмэх/хасах (болгоомжтой — ledger-т admin_adjust гэж бичигдэнэ). */
  @Post('users/:id/adjust-tokens')
  @HttpCode(200)
  async adjustTokens(@Param('id', ParseUUIDPipe) id: string, @Body() dto: AdjustTokensDto) {
    if (dto.amount === 0) throw new BadRequestException('amount 0 байж болохгүй');
    const newBalance = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.wallet.updateMany({
        where: { userId: id, ...(dto.amount < 0 ? { balance: { gte: -dto.amount } } : {}) },
        data: { balance: { increment: dto.amount } },
      });
      if (updated.count === 0) throw new BadRequestException('Үлдэгдэл хүрэлцэхгүй эсвэл данс алга.');
      await tx.tokenTransaction.create({
        data: { userId: id, amount: dto.amount, type: TokenTxType.admin_adjust, note: dto.note },
      });
      const wallet = await tx.wallet.findUniqueOrThrow({ where: { userId: id } });
      return wallet.balance;
    });
    this.realtime.emitToUser(id, 'wallet_updated', { balance: newBalance });
    return { ok: true, balance: newBalance };
  }

  // ---------- Payments / Orders ----------

  @Get('payments')
  payments() {
    return this.prisma.payment.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: { user: { select: { id: true, phone: true, name: true } }, package: true },
    });
  }

  @Get('orders')
  orders() {
    return this.prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: {
        winner: { select: { id: true, phone: true, name: true } },
        auction: { select: { id: true, title: true } },
      },
    });
  }

  @Patch('orders/:id/delivery')
  async updateDelivery(@Param('id', ParseUUIDPipe) id: string, @Body() body: Record<string, unknown>) {
    return this.prisma.order.update({
      where: { id },
      data: { deliveryInfo: body as any },
    });
  }

  // ---------- Packages ----------

  @Get('packages')
  packages() {
    return this.prisma.tokenPackage.findMany({ orderBy: { sortOrder: 'asc' } });
  }

  @Post('packages')
  createPackage(@Body() dto: UpsertPackageDto) {
    return this.prisma.tokenPackage.create({ data: dto });
  }

  @Patch('packages/:id')
  updatePackage(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpsertPackageDto) {
    return this.prisma.tokenPackage.update({ where: { id }, data: dto });
  }

  // ---------- Content ----------

  @Patch('content/:key')
  updateContent(@Param('key') key: string, @Body() dto: UpdateContentDto) {
    return this.prisma.appContent.upsert({
      where: { key },
      create: { key, ...dto },
      update: dto,
    });
  }
}
