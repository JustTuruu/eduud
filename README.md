# E-Duud — Дуудлага худалдааны платформ

naad.win загварын penny-auction платформ: санал (bid) бүр 1 token зарцуулна, хамгийн сүүлд санал өгсөн хүн ялагч болж эцсийн үнийг төлж бараагаа авна.

## Бүтэц

```
duud/
  backend-spring/ — Spring Boot + Kafka API (auth, wallet, auction engine, admin, Socket.IO)
  app/       — Flutter апп + web (нэг код: iOS/Android апп, landing page бүхий web сайт)
```

## Архитектур

- **API**: Java 17 / Spring Boot 3.5 + Kafka (саналын queue, partition = auctionId) + Socket.IO (netty-socketio, порт 3001)
- **DB**: Supabase managed Postgres (зөвхөн DB болгож ашиглана)
- **Файл**: Cloudflare R2 (presigned upload)
- **Төлбөр**: wire.mn (цэнэглэлт + ялагчийн төлбөр, webhook)
- **OTP**: verify.mn (бүртгэл, нууц үг сэргээх)

## Web (landing page)

Flutter апп web дээр мөн ажиллана — `/` нь нэвтрээгүй хэрэглэгчид landing page,
дуудлага худалдаануудыг шууд үзэж, нэвтрээд санал өгнө. Апп, web **яг ижил** үйлдэлтэй.
Дэлгэрэнгүйг [app/README.md](app/README.md) → «Web» хэсгээс.

```bash
cd app
flutter run -d chrome                     # dev
flutter build web --release --dart-define=API_URL=https://<api> --dart-define=SOCKET_URL=https://<socket>
```

## Backend ажиллуулах

Дэлгэрэнгүйг [backend-spring/README.md](backend-spring/README.md)-ээс үзнэ үү.

```bash
cd backend-spring
docker compose up -d postgres kafka
mvn package -DskipTests
java -jar target/eduud-backend-spring-0.1.0.jar --seed   # багц, админ, контент
java -jar target/eduud-backend-spring-0.1.0.jar          # API :3000, Socket.IO :3001
```

Dev горимд `OTP_PROVIDER=mock` (код консолд хэвлэгдэнэ), `WIRE_MODE=test`
(төлбөрийг `POST /payments/wire/test-pay/:invoiceId`-ээр симуляци хийнэ).

### Гадны бүртгэлүүд (эзэмшигч хийх)

| Үйлчилгээ | Юунд | Хаана |
|---|---|---|
| Supabase | Postgres DB | supabase.com — project үүсгээд Session/Transaction pooler URL-уудыг `.env`-д |
| Railway / Render | API hosting | GitHub repo холбоод deploy (`mvn package`, `java -jar target/eduud-backend-spring-0.1.0.jar`; Kafka шаардлагатай) |
| Cloudflare R2 | Зураг хадгалалт | R2 bucket + API token → `.env` |
| wire.mn | Төлбөр | Merchant бүртгэл (KYC) → API key, webhook URL: `https://<api>/payments/wire/webhook` |
| verify.mn | SMS OTP | Данс → API key (`OTP_PROVIDER=verifymn`) |
| Firebase | Push (FCM) | Дараагийн үе шатанд |

### Тест

```bash
cd backend-spring && mvn test   # unit: bid логик, soft/hard close
```

### Гол API-ууд

- `POST /auth/otp/request|verify`, `/auth/register|login|refresh|logout`, `/auth/password/reset`
- `GET/PATCH /me`, `POST /me/password`, `POST /media/presign`
- `GET /wallet|/wallet/packages|/wallet/transactions`, `POST /wallet/topup`, `POST /wallet/topup/:id/check`
- `GET /auctions?status=live|scheduled|ended`, `GET /auctions/:id`, `POST /auctions/:id/bid` (202 PENDING — Kafka-аар боловсрогдоно)
- `GET /orders`, `POST /orders/:id/pay`
- `GET /content/:key` (terms/privacy/faq), `POST /devices`
- `/admin/*` — auction CRUD/publish/cancel, users/ban, adjust-tokens, payments, orders, packages, content

### Socket.IO events

`join_auction`/`leave_auction` (client) → `bid_placed`, `auction_extended`,
`auction_started`, `auction_ended`, `auction_cancelled` (room), `wallet_updated`,
`outbid`, `auction_won`, `order_paid`, `bid_rejected` (хувийн, JWT handshake-тэй үед).

### Анхаарах TODO

- `WireService.java` / `OtpService.java` — endpoint, payload-ыг албан ёсны API
  бичиг баримттай тулгах (одоо test/mock горимд бүрэн ажиллана)
- FCM push, Flutter апп — дараагийн үе шат
# eduud
