# E-Duud — Дуудлага худалдааны платформ

naad.win загварын penny-auction платформ: санал (bid) бүр 1 token зарцуулна, хамгийн сүүлд санал өгсөн хүн ялагч болж эцсийн үнийг төлж бараагаа авна.

## Бүтэц

```
duud/
  backend/   — NestJS API (auth, wallet, auction engine, admin, Socket.IO)
  app/       — Flutter апп (хэрэглэгч + админ роль)   ← дараагийн үе шат
```

## Архитектур

- **API**: NestJS + Prisma + Socket.IO + pg-boss — Railway/Render дээр deploy
- **DB**: Supabase managed Postgres (зөвхөн DB болгож ашиглана)
- **Файл**: Cloudflare R2 (presigned upload)
- **Төлбөр**: wire.mn (цэнэглэлт + ялагчийн төлбөр, webhook)
- **OTP**: verify.mn (бүртгэл, нууц үг сэргээх)

## Backend ажиллуулах

```bash
cd backend
npm install
copy .env.example .env    # утгуудаа бөглөнө
npm run db:migrate        # Supabase руу migration
npm run db:seed           # багц, админ, контент seed
npm run start:dev
```

Dev горимд `OTP_PROVIDER=mock` (код консолд хэвлэгдэнэ), `WIRE_MODE=test`
(төлбөрийг `POST /payments/wire/test-pay/:invoiceId`-ээр симуляци хийнэ).

### Гадны бүртгэлүүд (эзэмшигч хийх)

| Үйлчилгээ | Юунд | Хаана |
|---|---|---|
| Supabase | Postgres DB | supabase.com — project үүсгээд Session/Transaction pooler URL-уудыг `.env`-д |
| Railway / Render | API hosting | GitHub repo холбоод deploy (`build`: `npm run build`, `start`: `npm run deploy:start`) |
| Cloudflare R2 | Зураг хадгалалт | R2 bucket + API token → `.env` |
| wire.mn | Төлбөр | Merchant бүртгэл (KYC) → API key, webhook URL: `https://<api>/payments/wire/webhook` |
| verify.mn | SMS OTP | Данс → API key (`OTP_PROVIDER=verifymn`) |
| Firebase | Push (FCM) | Дараагийн үе шатанд |

### Тест

```bash
npm test          # unit: bid логик, soft/hard close, webhook idempotency
```

### Гол API-ууд

- `POST /auth/otp/request|verify`, `/auth/register|login|refresh|logout`, `/auth/password/reset`
- `GET/PATCH /me`, `POST /me/password`, `POST /media/presign`
- `GET /wallet|/wallet/packages|/wallet/transactions`, `POST /wallet/topup`, `POST /wallet/topup/:id/check`
- `GET /auctions?status=live|scheduled|ended`, `GET /auctions/:id`, `POST /auctions/:id/bid`
- `GET /orders`, `POST /orders/:id/pay`
- `GET /content/:key` (terms/privacy/faq), `POST /devices`
- `/admin/*` — auction CRUD/publish/cancel, users/ban, adjust-tokens, payments, orders, packages, content

### Socket.IO events

`join_auction`/`leave_auction` (client) → `bid_placed`, `auction_extended`,
`auction_started`, `auction_ended`, `auction_cancelled` (room), `wallet_updated`,
`outbid`, `auction_won`, `order_paid` (хувийн, JWT handshake-тэй үед).

### Анхаарах TODO

- `wire.service.ts` / `otp.service.ts` — endpoint, payload-ыг албан ёсны API
  бичиг баримттай тулгах (одоо test/mock горимд бүрэн ажиллана)
- FCM push, Flutter апп — дараагийн үе шат
