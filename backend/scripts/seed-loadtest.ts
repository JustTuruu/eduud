/**
 * Load test-ийн бэлтгэл: 50 туршилтын хэрэглэгч (тус бүр 20 token) +
 * 1 live auction үүсгэнэ.
 *
 * Ажиллуулах: npx ts-node -T scripts/seed-loadtest.ts
 */
import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();
const USER_COUNT = 50;
const PASSWORD = 'loadtest123';

async function main() {
  const admin = await prisma.user.findFirst({ where: { role: 'admin' } });
  if (!admin) throw new Error('Эхлээд npm run db:seed ажиллуулна уу (админ хэрэгтэй).');

  const passwordHash = await argon2.hash(PASSWORD);
  const phones: string[] = [];
  for (let i = 0; i < USER_COUNT; i++) {
    const phone = `90${(100000 + i).toString()}`;
    phones.push(phone);
    await prisma.user.upsert({
      where: { phone },
      create: {
        phone,
        name: `LoadTest ${i}`,
        passwordHash,
        wallet: { create: { balance: 20 } },
      },
      update: { wallet: { upsert: { create: { balance: 20 }, update: { balance: 20 } } } },
    });
  }

  const now = new Date();
  const auction = await prisma.auction.create({
    data: {
      title: `Load test auction ${now.toISOString()}`,
      description: 'Зэрэгцээ bid-ийн атомик байдлын туршилт',
      images: [],
      startPrice: 100,
      increment: 10,
      currentPrice: 100,
      softCloseSec: 15,
      extendSec: 15,
      startsAt: now,
      endsAt: new Date(now.getTime() + 10 * 60 * 1000),
      status: 'live',
      createdById: admin.id,
    },
  });

  console.log(JSON.stringify({ auctionId: auction.id, phones, password: PASSWORD }, null, 2));
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
