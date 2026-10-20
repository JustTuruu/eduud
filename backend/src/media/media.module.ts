import { Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { R2Service } from './r2.service';

@Module({
  controllers: [MediaController],
  providers: [R2Service],
})
export class MediaModule {}
