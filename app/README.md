# E-Duud Flutter апп

Luxe Navy дизайн системтэй (батлагдсан mockup-аас):
`lib/core/theme/app_theme.dart` — өнгөний токен, Unbounded + Manrope typography.

## Анх удаа ажиллуулах

Flutter SDK суулгасны дараа (https://docs.flutter.dev/get-started/install/windows):

```bash
cd app
flutter create . --platforms=android,ios   # платформын хавтсуудыг үүсгэнэ (lib/-д нөлөөлөхгүй)
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3000
```

- Android emulator: `http://10.0.2.2:3000` (default)
- Бодит төхөөрөмж: `--dart-define=API_URL=http://<компьютерийн-LAN-IP>:3000`
- Web (Chrome): `flutter run -d chrome` — default `http://localhost:3000`

## Web (landing page + дуудлага худалдаа)

Апп болон web **нэг кодын бааз** — үйлдэл нь яг ижил, зөвхөн зай хуваарилалт
responsive (`lib/shared/responsive.dart`):

- Нэвтрээгүй үед `/` нь landing page (`features/landing/`): танилцуулга +
  идэвхтэй auction-ууд шууд харагдана. Карт дээр дарвал `/auctions/:id`
  нээлттэй харагдана (realtime үнэ, countdown); «Санал өгөх» дарвал нэвтрэх
  дэлгэц рүү `?next=` параметртэй очиж, нэвтэрсний дараа буцаж ирнэ.
- ≥ 900px өргөнд доод навигацийн оронд дээд навигац, auction жагсаалт 2–3
  баганатай grid, хуудсууд төвдөө хязгаарлагдана.
- URL нь `#`-гүй path хэлбэртэй (`usePathUrlStrategy`) — hosting дээр SPA
  fallback хэрэгтэй. `web/vercel.json` (Vercel) болон `web/_redirects`
  (Netlify) build-д автоматаар орно.
- Token web дээр `localStorage`-д (`core/storage/`), утас дээр secure storage-д.

```bash
flutter run -d chrome                                          # dev, backend localhost:3000
flutter build web --release \
  --dart-define=API_URL=https://api.example.mn \
  --dart-define=SOCKET_URL=https://socket.example.mn            # build/web → static hosting
```

Backend-ийн CORS (`WebConfig.java`) болон Socket.IO origin (`RealtimeGateway.java`)
аль хэдийн `*` тул web-ээс холбогдоход нэмэлт тохиргоо хэрэггүй. Socket.IO
тусдаа порт (3001) дээр ажилладаг тул production-д түүнийг ч https-ээр нээх
хэрэгтэй (`SOCKET_URL`).
- Backend нь `WIRE_MODE=test`, `OTP_PROVIDER=mock` горимд бүрэн туршигдана
  (OTP код backend-ийн консолд хэвлэгдэнэ).

## Бүтэц

```
lib/
  core/        theme (Luxe Navy), config, models, dio+JWT interceptor, Socket.IO, router
  features/
    landing/   нэвтрээгүй хэрэглэгчийн landing page (hero, live auction grid, how-it-works)
    auth/      нэвтрэх, бүртгэл (утас→OTP→нэр/нууц үг), нууц үг сэргээх
    home/      идэвхтэй/удахгүй/дууссан таб, auction карт (countdown, LIVE badge)
    auction/   дэлгэрэнгүй: realtime bid feed, том countdown (сүүлийн 15 сек pulse),
               «Санал өгөх» CTA, soft-close сунгалт socket-оор
    wallet/    үлдэгдэл, багц, wire.mn нэхэмжлэх, «төлбөр шалгах», гүйлгээний түүх
    orders/    ялсан бараа, эцсийн төлбөр
    profile/   нэр/нууц үг солих, нөхцөл/нууцлал, гарах
    content/   terms/privacy/faq (backend-ээс)
  shared/      PrimaryButton (press glow), CountdownText (pulse), LiveBadge, PriceText,
               responsive.dart (Breakpoints, PageFrame), app_nav_bar.dart (доод + дээд нав, Wordmark)
```

## Дараагийн үе шат (TODO)

- Админ дэлгэцүүд (auction үүсгэх/нийтлэх, зурaг upload, цэнэглэлт хянах)
- Avatar upload (R2 presign бэлэн, image_picker нэмэх)
- FCM push мэдэгдэл
- QR-ыг зурган хэлбэрээр үзүүлэх (qr_flutter), deeplink нээх (url_launcher)
