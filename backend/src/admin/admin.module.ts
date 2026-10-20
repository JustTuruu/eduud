import { Module } from '@nestjs/common';
import { AuctionsModule } from '../auctions/auctions.module';
import { AdminController } from './admin.controller';

@Module({
  imports: [AuctionsModule],
  controllers: [AdminController],
})
export class AdminModule {}
