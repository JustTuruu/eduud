/**
 * Bid race load test: 50 хэрэглэгч зэрэг bid хийж, дараа нь ledger-ийн
 * зөрүүг шалгана.
 *
 * 1. npx ts-node -T scripts/seed-loadtest.ts   (auctionId хэвлэнэ)
 * 2. npx ts-node -T scripts/bid-race.ts <auctionId>
 *
 * Хүлээгдэх үр дүн:
 *  - bids.count === амжилттай bid-ийн тоо === auction.bidCount
 *  - currentPrice === startPrice + bids.count * increment
 *  - хэрэглэгч бүрийн balance === 20 - тухайн хэрэглэгчийн амжилттай bid
 *  - SUM(token_transactions) === wallets.balance (бүх хэрэглэгч дээр)
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const API = process.env.API_URL ?? 'http://localhost:3000';
const USER_COUNT = 50;
const BIDS_PER_USER = 5;
const PASSWORD = 'loadtest123';

async function login(phone: string): Promise<string> {
  const res = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, password: PASSWORD }),
  });
  if (!res.ok) throw new Error(`login ${phone}: ${res.status}`);
  return ((await res.json()) as any).accessToken;
}

async function main() {
  const auctionId = process.argv[2];
  if (!auctionId) throw new Error('Хэрэглээ: ts-node scripts/bid-race.ts <auctionId>');

  const phones = Array.from({ length: USER_COUNT }, (_, i) => `90${100000 + i}`);
  console.log(`${USER_COUNT} хэрэглэгч нэвтэрч байна...`);
  const tokens = await Promise.all(phones.map(login));

  console.log(`Зэрэг bid буудаж байна (${USER_COUNT} x ${BIDS_PER_USER})...`);
  let ok = 0;
  let rejected = 0;
  await Promise.all(
    tokens.flatMap((token) =>
      Array.from({ length: BIDS_PER_USER }, () =>
        fetch(`${API}/auctions/${auctionId}/bid`, {
          method: 'POST',
          headers: { Authorization: `Bearer ${token}` },
        }).then(async (r) => {
          if (r.ok) ok++;
          else rejected++;
        }),
      ),
    ),
  );
  console.log(`Амжилттай: ${ok}, Татгалзсан (дараалсан bid г.м.): ${rejected}`);

  // --- Тулгалт ---
  const auction = await prisma.auction.findUniqueOrThrow({ where: { id: auctionId } });
  const bidCount = await prisma.bid.count({ where: { auctionId } });
  const expectedPrice = auction.startPrice + bidCount * auction.increment;

  const problems: string[] = [];
  if (bidCount !== ok) problems.push(`bids.count=${bidCount} !== амжилттай=${ok}`);
  if (auction.bidCount !== bidCount)
    problems.push(`auction.bidCount=${auction.bidCount} !== bids.count=${bidCount}`);
  if (auction.currentPrice !== expectedPrice)
    problems.push(`currentPrice=${auction.currentPrice} !== ${expectedPrice}`);

  const users = await prisma.user.findMany({
    where: { phone: { in: phones } },
    include: { wallet: true },
  });
  for (const u of users) {
    const spent = await prisma.bid.count({ where: { auctionId, userId: u.id } });
    const ledgerSum = await prisma.tokenTransaction.aggregate({
      where: { userId: u.id },
      _sum: { amount: true },
    });
    const balance = u.wallet?.balance ?? 0;
    if (balance !== 20 - spent)
      problems.push(`${u.phone}: balance=${balance}, хүлээгдэж буй=${20 - spent}`);
    // Seed нь balance=20-г ledger бичилтгүй өгсөн тул: 20 + SUM(ledger) === balance
    if (20 + (ledgerSum._sum.amount ?? 0) !== balance)
      problems.push(
        `${u.phone}: ledger нийлбэр ${ledgerSum._sum.amount ?? 0} нь balance=${balance}-тай зөрүүтэй`,
      );
  }

  if (problems.length === 0) {
    console.log('✅ БҮХ ТУЛГАЛТ ЗӨВ: token хасалт, үнэ, ledger зөрүүгүй.');
  } else {
    console.error('❌ Зөрүү илэрлээ:');
    problems.forEach((p) => console.error('  - ' + p));
    process.exit(1);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
