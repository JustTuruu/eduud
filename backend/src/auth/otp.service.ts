import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { OtpPurpose } from '@prisma/client';
import { createHash, randomInt } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

const OTP_TTL_MIN = 5;
const MAX_ATTEMPTS = 5;
const MIN_RESEND_SEC = 60;
const MAX_PER_DAY = 5;

/** SMS илгээгч интерфейс — mock (dev) болон verify.mn (prod). */
interface SmsSender {
  send(phone: string, code: string): Promise<void>;
}

class MockSender implements SmsSender {
  private readonly logger = new Logger('MockSms');
  async send(phone: string, code: string) {
    this.logger.warn(`[MOCK OTP] ${phone} -> ${code}`);
  }
}

class VerifyMnSender implements SmsSender {
  async send(phone: string, code: string) {
    const res = await fetch(`${process.env.VERIFYMN_API_URL}/api/v1/sms/send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.VERIFYMN_API_KEY}`,
      },
      body: JSON.stringify({
        phone,
        message: `E-Duud баталгаажуулах код: ${code}`,
      }),
    });
    if (!res.ok) {
      throw new Error(`verify.mn SMS илгээхэд алдаа: ${res.status} ${await res.text()}`);
    }
  }
}

@Injectable()
export class OtpService {
  /** mock үед SMS яг илгээгддэггүй тул кодыг клиент рүү буцааж тест хийх боломжтой. */
  readonly isMock = process.env.OTP_PROVIDER !== 'verifymn';

  private readonly sender: SmsSender = this.isMock ? new MockSender() : new VerifyMnSender();

  constructor(private readonly prisma: PrismaService) {}

  private hash(code: string): string {
    return createHash('sha256').update(`${code}:${process.env.JWT_ACCESS_SECRET}`).digest('hex');
  }

  /**
   * OTP үүсгээд илгээнэ.
   * @returns mock горимд кодыг өөрийг нь, эсрэг тохиолдолд null.
   *          Кодыг зөвхөн OTP_PROVIDER=mock (dev/test) үед буцаана — production-д
   *          verifymn ашиглагддаг тул хэзээ ч гадагш гарахгүй.
   */
  async request(phone: string, purpose: OtpPurpose): Promise<string | null> {
    const dayAgo = new Date(Date.now() - 24 * 3600 * 1000);
    const recent = await this.prisma.otpCode.findMany({
      where: { phone, purpose, createdAt: { gte: dayAgo } },
      orderBy: { createdAt: 'desc' },
    });
    if (recent.length >= MAX_PER_DAY) {
      throw new BadRequestException('Өдрийн OTP хязгаарт хүрсэн. Маргааш дахин оролдоно уу.');
    }
    const last = recent[0];
    if (last && Date.now() - last.createdAt.getTime() < MIN_RESEND_SEC * 1000) {
      throw new BadRequestException('Түр хүлээгээд дахин код авна уу.');
    }

    const code = randomInt(100000, 1000000).toString();
    await this.prisma.otpCode.create({
      data: {
        phone,
        purpose,
        codeHash: this.hash(code),
        expiresAt: new Date(Date.now() + OTP_TTL_MIN * 60 * 1000),
      },
    });
    await this.sender.send(phone, code);
    return this.isMock ? code : null;
  }

  /** Кодыг шалгаад амжилттай бол used гэж тэмдэглэнэ. */
  async verify(phone: string, purpose: OtpPurpose, code: string): Promise<void> {
    const otp = await this.prisma.otpCode.findFirst({
      where: { phone, purpose, usedAt: null, expiresAt: { gte: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp) throw new BadRequestException('Код хүчингүй эсвэл хугацаа дууссан.');
    if (otp.attempts >= MAX_ATTEMPTS) {
      throw new BadRequestException('Хэт олон буруу оролдлого. Шинэ код авна уу.');
    }
    if (otp.codeHash !== this.hash(code)) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Код буруу байна.');
    }
    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { usedAt: new Date() },
    });
  }
}
