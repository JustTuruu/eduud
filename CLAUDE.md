# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Төсөл

E-Duud — penny-auction платформ: bid бүр 1 token зарцуулна, хамгийн сүүлд bid хийсэн хэрэглэгч ялж эцсийн үнийг төлөөд бараагаа авна. Monorepo, git repo биш:

- `backend/` — NestJS API (Prisma + Postgres/Supabase, Socket.IO, pg-boss)
- `app/` — Flutter апп (Riverpod + go_router + dio + socket_io_client)

Код доторх коммент, хэрэглэгчид харагдах бүх мессеж **монгол хэлээр** бичигдэнэ — энэ хэв маягийг барих.

## Командууд

### Backend (`backend/` дотор)

```bash
npm install
npm run db:migrate        # prisma migrate dev (DIRECT_URL ашиглана)
npm run db:seed           # багц, админ, контент seed (prisma/seed.ts)
npm run start:dev         # ts-node -T src/main.ts (watch байхгүй)
npm run build             # prisma generate + tsc
npm test                  # vitest run — бүх unit test
npx vitest run src/auctions/auction.logic.spec.ts   # ганц test файл
```

Deploy (Railway/Render): build = `npm run build`, start = `npm run deploy:start` (migrate deploy + node dist/main.js).

Dev горим: `OTP_PROVIDER=mock` (OTP код консолд хэвлэгдэнэ), `WIRE_MODE=test` (төлбөрийг `POST /payments/wire/test-pay/:invoiceId`-ээр симуляци хийнэ).

### App (`app/` дотор)

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000   # emulator; бодит төхөөрөмжид LAN IP
flutter run -d chrome                                     # web — landing page + бүх дэлгэц
flutter build web --release                               # build/web → static hosting (SPA fallback хэрэгтэй)
flutter test
```

`API_URL` өгөхгүй бол default нь Android-д `http://10.0.2.2:3000`, web-д `http://localhost:3000` ([config.dart](app/lib/core/config.dart)).

Web = апп нэг код. Нэвтрээгүй үед `/` нь landing ([landing_screen.dart](app/lib/features/landing/landing_screen.dart)), `/auctions/:id` нээлттэй; нэвтрэлт шаардах замууд `?next=`-тэй login руу redirect хийгдэнэ. Responsive дүрэм [responsive.dart](app/lib/shared/responsive.dart): ≥900px дээр дээд нав, grid. Token web дээр localStorage ([core/storage/](app/lib/core/storage/)).

## Архитектур

### DB холболт — хоёр URL заавал ялгаатай үүрэгтэй

- `DATABASE_URL` — Supabase transaction pooler (порт 6543, `pgbouncer=true`) — Prisma runtime query
- `DIRECT_URL` — direct connection (порт 5432) — migration **болон pg-boss**. pg-boss нь pgBouncer transaction mode-той зохицдоггүй тул [jobs.service.ts](backend/src/jobs/jobs.service.ts) заавал `DIRECT_URL`/`PGBOSS_URL` ашиглана. `DIRECT_URL` байхгүй бол job scheduler чимээгүй идэвхгүй болно (auction автоматаар эхлэх/дуусахгүй).

### Auction lifecycle — pg-boss delayed job-оор хөтлөгдөнө

Төлөв: `draft → scheduled → live → ended → settled` (+`cancelled`). Гол зохион байгуулагч нь [auctions.service.ts](backend/src/auctions/auctions.service.ts):

- 3 queue: `auction-start`, `auction-finalize`, `order-expire`. Worker-ууд `onModuleInit`-д бүртгэгдэж, restart-ын дараа `recoverSchedules()` live/scheduled auction-уудын job-ыг дахин товлоно (давхар товлолт хоргүй — handler бүр status guard-тай).
- Soft-close: bid ирэхэд `endsAt` сунгагдвал finalize job шинэ хугацаанд дахин илгээгдэнэ; хуучин job ажиллахдаа `ends_at > now` гэдгийг хараад өөрийгөө дахин товлоод гарна.
- Ялагч гарвал finalize нь `Order` (payDeadline-тэй) үүсгэж `order-expire` job товлоно.

### Bid — атомик цөм

`placeBid` нь нэг transaction дотор: `SELECT ... FOR UPDATE`-ээр auction мөрийг түгжиж (зэрэгцээ bid дараалалд орно) → `wallet.updateMany({balance: {gte: 1}})`-ээр token хасна (count=0 бол үлдэгдэл хүрэлцээгүй) → bid, auction update, tokenTransaction бичнэ. Socket broadcast болон job товлолт transaction-ы **гадна** хийгдэнэ.

Bid-ийн цэвэр дүрэм (validateBid, computeNewEndsAt) нь DB-ээс хараат бус [auction.logic.ts](backend/src/auctions/auction.logic.ts)-д тусгаарлагдсан — unit test энд бичигдэнэ. Шинэ bid дүрэм нэмэхдээ энэ файлд нэмж spec-ээр нь тестлэх.

### Төлбөр — idempotent settle

[payments.service.ts](backend/src/payments/payments.service.ts)-ийн `settle()` нь `updateMany({status: pending} → paid)` guard-тай: wire.mn webhook давхар ирсэн ч token давхар нэмэгдэхгүй. Төлбөр батлагдсаны бүх үр дагавар (topup → wallet increment, order → paid) энэ нэг цэгээр явна.

### Auth — global guard, default нь хаалттай

`JwtAuthGuard` + `RolesGuard` нь `APP_GUARD`-аар глобал ([app.module.ts](backend/src/app.module.ts)). Endpoint бүр default-оороо JWT шаардана; нээлттэй болгохдоо `@Public()`, админ болгохдоо `@Roles('admin')` decorator ([decorators.ts](backend/src/common/decorators.ts)). Хэрэглэгчийг `@CurrentUser()`-ээр авна.

### Realtime — Socket.IO room-ууд

[realtime.gateway.ts](backend/src/realtime/realtime.gateway.ts): `auction:{id}` room нээлттэй (`join_auction`/`leave_auction`), `user:{id}` room нь handshake-ийн `auth.token` JWT-ээр автоматаар join хийгдэнэ. Event бүрт `serverTime` дагалдана — клиент clock offset засахад. Service-үүд `emitToAuction`/`emitToUser` helper-ээр broadcast хийнэ.

### Flutter апп

- Riverpod бүхэлдээ; auth төлөв [auth_controller.dart](app/lib/features/auth/auth_controller.dart), router нь `authProvider.select(...)`-оор зөвхөн нэвтэрсэн эсэх өөрчлөгдөхөд дахин үүснэ ([router.dart](app/lib/core/router.dart) доторх коммент энэ талаар чухал — navigation тэглэгдэхээс сэргийлдэг).
- [api_client.dart](app/lib/core/api/api_client.dart): dio interceptor 401 үед refresh token-оор нэг удаа дахин оролдоно; token-ууд flutter_secure_storage-д. Backend-ийн монгол алдааны мессежийг `apiErrorMessage()`-ээр гаргана.
- Дэлгэцүүд `app/lib/features/<feature>/` дотор, нийтлэг widget `app/lib/shared/`.

### Гадны үйлчилгээ

wire.mn (төлбөр) ба verify.mn (OTP) — [wire.service.ts](backend/src/payments/wire.service.ts), [otp.service.ts](backend/src/auth/otp.service.ts)-ийн endpoint/payload-ыг албан ёсны API бичиг баримттай хараахан тулгаагүй (test/mock горимд бүрэн ажиллана). Cloudflare R2 — presigned upload ([r2.service.ts](backend/src/media/r2.service.ts)). FCM push болон Firebase дараагийн үе шат.
