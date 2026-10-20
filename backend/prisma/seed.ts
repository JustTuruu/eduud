import { PrismaClient } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

async function main() {
  // Token багцууд
  const packages = [
    { tokens: 15, priceMnt: 15000, sortOrder: 1 },
    { tokens: 30, priceMnt: 24000, sortOrder: 2 },
    { tokens: 50, priceMnt: 35000, sortOrder: 3 },
    { tokens: 100, priceMnt: 65000, sortOrder: 4 },
  ];
  for (const pkg of packages) {
    const exists = await prisma.tokenPackage.findFirst({ where: { tokens: pkg.tokens } });
    if (!exists) await prisma.tokenPackage.create({ data: pkg });
  }

  // Админ хэрэглэгч
  const adminPhone = process.env.SEED_ADMIN_PHONE ?? '99000000';
  const adminPassword = process.env.SEED_ADMIN_PASSWORD ?? 'admin1234';
  await prisma.user.upsert({
    where: { phone: adminPhone },
    create: {
      phone: adminPhone,
      name: 'Админ',
      passwordHash: await argon2.hash(adminPassword),
      role: 'admin',
      wallet: { create: { balance: 0 } },
    },
    update: { role: 'admin' },
  });

  // Контентын placeholder-ууд
  const contents = [
    { key: 'terms', title: 'Үйлчилгээний нөхцөл', body: 'Энд үйлчилгээний нөхцөлөө оруулна уу.' },
    { key: 'privacy', title: 'Нууцлалын бодлого', body: 'Энд нууцлалын бодлогоо оруулна уу.' },
    { key: 'faq', title: 'Түгээмэл асуулт', body: 'Энд түгээмэл асуулт хариултаа оруулна уу.' },
  ];
  for (const c of contents) {
    await prisma.appContent.upsert({
      where: { key: c.key },
      create: c,
      update: {},
    });
  }

  console.log(`Seed дууслаа. Админ: ${adminPhone} / ${adminPassword}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
