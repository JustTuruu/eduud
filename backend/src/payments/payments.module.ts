import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { WireService } from './wire.service';

@Module({
  controllers: [PaymentsController],
  providers: [PaymentsService, WireService],
  exports: [PaymentsService, WireService],
})
export class PaymentsModule {}
