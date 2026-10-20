import { Body, Controller, Get, HttpCode, Param, Post } from '@nestjs/common';
import { IsUUID } from 'class-validator';
import { AuthUser, CurrentUser } from '../common/decorators';
import { PaymentsService } from '../payments/payments.service';
import { WalletService } from './wallet.service';

class TopupDto {
  @IsUUID()
  packageId: string;
}

@Controller('wallet')
export class WalletController {
  constructor(
    private readonly wallet: WalletService,
    private readonly payments: PaymentsService,
  ) {}

  @Get()
  balance(@CurrentUser() user: AuthUser) {
    return this.wallet.balance(user.id);
  }

  @Get('packages')
  packages() {
    return this.wallet.packages();
  }

  @Get('transactions')
  transactions(@CurrentUser() user: AuthUser) {
    return this.wallet.transactions(user.id);
  }

  @Post('topup')
  topup(@CurrentUser() user: AuthUser, @Body() dto: TopupDto) {
    return this.wallet.topup(user.id, dto.packageId);
  }

  /** Webhook алдагдсан үеийн fallback — төлбөрөө гараар шалгах. */
  @Post('topup/:paymentId/check')
  @HttpCode(200)
  check(@CurrentUser() user: AuthUser, @Param('paymentId') paymentId: string) {
    return this.payments.checkAndSettle(user.id, paymentId);
  }
}
