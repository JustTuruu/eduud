import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AuthUser, CurrentUser, Roles } from '../common/decorators';
import { PrismaService } from '../prisma/prisma.service';
import { CreateFeedbackDto, UpdateFeedbackDto } from './feedback.dto';

const LIST_SELECT = {
  id: true,
  type: true,
  category: true,
  message: true,
  status: true,
  adminNote: true,
  createdAt: true,
};

@Controller('feedback')
export class FeedbackController {
  constructor(private readonly prisma: PrismaService) {}

  /** Санал хүсэлт илгээх. */
  @Post()
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateFeedbackDto) {
    const created = await this.prisma.feedback.create({
      data: {
        userId: user.id,
        type: dto.type,
        category: dto.category,
        message: dto.message,
        appVersion: dto.appVersion,
        platform: dto.platform,
      },
      select: LIST_SELECT,
    });
    return created;
  }

  /** Өөрийн илгээсэн саналуудын түүх. */
  @Get('mine')
  mine(@CurrentUser() user: AuthUser) {
    return this.prisma.feedback.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: LIST_SELECT,
    });
  }

  // ---------- Админ ----------

  @Get('admin')
  @Roles(UserRole.admin)
  adminList(@Query('status') status?: string) {
    return this.prisma.feedback.findMany({
      where: status ? { status: status as never } : undefined,
      orderBy: { createdAt: 'desc' },
      take: 200,
      include: {
        user: { select: { id: true, name: true, phone: true } },
      },
    });
  }

  @Patch('admin/:id')
  @Roles(UserRole.admin)
  adminUpdate(@Param('id') id: string, @Body() dto: UpdateFeedbackDto) {
    return this.prisma.feedback.update({
      where: { id },
      data: { status: dto.status, adminNote: dto.adminNote },
      select: LIST_SELECT,
    });
  }
}
