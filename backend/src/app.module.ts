import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { JobsModule } from './jobs/jobs.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { MediaModule } from './media/media.module';
import { WalletModule } from './wallet/wallet.module';
import { PaymentsModule } from './payments/payments.module';
import { AuctionsModule } from './auctions/auctions.module';
import { RealtimeModule } from './realtime/realtime.module';
import { OrdersModule } from './orders/orders.module';
import { ContentModule } from './content/content.module';
import { FeedbackModule } from './feedback/feedback.module';
import { DevicesModule } from './devices/devices.module';
import { AdminModule } from './admin/admin.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    JobsModule,
    AuthModule,
    UsersModule,
    MediaModule,
    WalletModule,
    PaymentsModule,
    AuctionsModule,
    RealtimeModule,
    OrdersModule,
    ContentModule,
    FeedbackModule,
    DevicesModule,
    AdminModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
