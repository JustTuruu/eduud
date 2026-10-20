import { Controller, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../common/decorators';
import { PaymentsService } from '../payments/payments.service';
import { OrdersService } from './orders.service';

@Controller('orders')
export class OrdersController {
  constructor(
    private readonly orders: OrdersService,
    private readonly payments: PaymentsService,
  ) {}

  @Get()
  myOrders(@CurrentUser() user: AuthUser) {
    return this.orders.myOrders(user.id);
  }

  @Post(':id/pay')
  @HttpCode(200)
  pay(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.orders.pay(user.id, id);
  }

  @Post(':id/payments/:paymentId/check')
  @HttpCode(200)
  check(@CurrentUser() user: AuthUser, @Param('paymentId', ParseUUIDPipe) paymentId: string) {
    return this.payments.checkAndSettle(user.id, paymentId);
  }
}
