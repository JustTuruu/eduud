import { Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { AuthUser, CurrentUser, Public } from '../common/decorators';
import { AuctionsService } from './auctions.service';

@Controller('auctions')
export class AuctionsController {
  constructor(private readonly auctions: AuctionsService) {}

  @Public()
  @Get()
  list(@Query('status') status?: 'live' | 'scheduled' | 'ended') {
    return this.auctions.list(status);
  }

  @Public()
  @Get(':id')
  detail(@Param('id', ParseUUIDPipe) id: string) {
    return this.auctions.detail(id);
  }

  @Post(':id/bid')
  @HttpCode(200)
  bid(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.auctions.placeBid(id, user.id);
  }
}
