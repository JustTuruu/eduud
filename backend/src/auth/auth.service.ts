import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { OtpPurpose, User } from '@prisma/client';
import * as argon2 from 'argon2';
import { createHash, randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from './otp.service';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly otp: OtpService,
  ) {}

  // ---------- OTP ----------

  async requestOtp(phone: string, purpose: OtpPurpose) {
    const exists = await this.prisma.user.findUnique({ where: { phone } });
    if (purpose === OtpPurpose.register && exists) {
      throw new ConflictException('Энэ дугаар бүртгэлтэй байна. Нэвтэрнэ үү.');
    }
    if (purpose === OtpPurpose.reset && !exists) {
      throw new BadRequestException('Энэ дугаар бүртгэлгүй байна.');
    }
    const devCode = await this.otp.request(phone, purpose);
    // devCode зөвхөн mock (dev/test) горимд утгатай — үүнийг апп "Тест орчны код"
    // болгож харуулна.
    return { ok: true, devCode };
  }

  /** OTP зөв бол 10 минутын ticket (JWT) буцаана — register/reset дуусгахад ашиглана. */
  async verifyOtp(phone: string, purpose: OtpPurpose, code: string) {
    await this.otp.verify(phone, purpose, code);
    const ticket = await this.jwt.signAsync(
      { phone, purpose, kind: 'otp-ticket' },
      { secret: process.env.JWT_ACCESS_SECRET, expiresIn: '10m' },
    );
    return { ticket };
  }

  private async consumeTicket(ticket: string, purpose: OtpPurpose): Promise<string> {
    try {
      const payload = await this.jwt.verifyAsync(ticket, {
        secret: process.env.JWT_ACCESS_SECRET,
      });
      if (payload.kind !== 'otp-ticket' || payload.purpose !== purpose) throw new Error();
      return payload.phone;
    } catch {
      throw new UnauthorizedException('Ticket хүчингүй. OTP-оо дахин баталгаажуулна уу.');
    }
  }

  // ---------- Register / Login ----------

  async register(ticket: string, name: string, password: string) {
    const phone = await this.consumeTicket(ticket, OtpPurpose.register);
    const exists = await this.prisma.user.findUnique({ where: { phone } });
    if (exists) throw new ConflictException('Энэ дугаар бүртгэлтэй байна.');

    const user = await this.prisma.user.create({
      data: {
        phone,
        name,
        passwordHash: await argon2.hash(password),
        wallet: { create: { balance: 0 } },
      },
    });
    return this.issueTokens(user);
  }

  async login(phone: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user || !(await argon2.verify(user.passwordHash, password))) {
      throw new UnauthorizedException('Дугаар эсвэл нууц үг буруу байна.');
    }
    if (user.status === 'banned') {
      throw new UnauthorizedException('Таны эрх хаагдсан байна.');
    }
    return this.issueTokens(user);
  }

  async resetPassword(ticket: string, newPassword: string) {
    const phone = await this.consumeTicket(ticket, OtpPurpose.reset);
    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) throw new BadRequestException('Хэрэглэгч олдсонгүй.');
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash: await argon2.hash(newPassword) },
      }),
      // Бүх төхөөрөмжөөс гаргана
      this.prisma.refreshToken.updateMany({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
    return { ok: true };
  }

  // ---------- Refresh rotation ----------

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private async issueTokens(user: User): Promise<TokenPair & { user: object }> {
    const accessToken = await this.jwt.signAsync(
      { sub: user.id, role: user.role },
      {
        secret: process.env.JWT_ACCESS_SECRET,
        expiresIn: Number(process.env.JWT_ACCESS_TTL_SEC ?? 900),
      },
    );
    const refreshToken = randomBytes(48).toString('base64url');
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: this.hashToken(refreshToken),
        expiresAt: new Date(Date.now() + Number(process.env.JWT_REFRESH_TTL_SEC ?? 2592000) * 1000),
      },
    });
    return {
      accessToken,
      refreshToken,
      user: { id: user.id, phone: user.phone, name: user.name, avatarUrl: user.avatarUrl, role: user.role },
    };
  }

  async refresh(refreshToken: string) {
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: this.hashToken(refreshToken) },
      include: { user: true },
    });
    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Дахин нэвтэрнэ үү.');
    }
    // Rotate: хуучныг хүчингүй болгоод шинийг олгоно
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });
    return this.issueTokens(stored.user);
  }

  async logout(refreshToken: string) {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: this.hashToken(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }
}
