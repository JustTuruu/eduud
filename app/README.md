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
- Backend нь `WIRE_MODE=test`, `OTP_PROVIDER=mock` горимд бүрэн туршигдана
  (OTP код backend-ийн консолд хэвлэгдэнэ).

## Бүтэц

```
lib/
  core/        theme (Luxe Navy), config, models, dio+JWT interceptor, Socket.IO, router
  features/
    auth/      нэвтрэх, бүртгэл (утас→OTP→нэр/нууц үг), нууц үг сэргээх
    home/      идэвхтэй/удахгүй/дууссан таб, auction карт (countdown, LIVE badge)
    auction/   дэлгэрэнгүй: realtime bid feed, том countdown (сүүлийн 15 сек pulse),
               «Санал өгөх» CTA, soft-close сунгалт socket-оор
    wallet/    үлдэгдэл, багц, wire.mn нэхэмжлэх, «төлбөр шалгах», гүйлгээний түүх
    orders/    ялсан бараа, эцсийн төлбөр
    profile/   нэр/нууц үг солих, нөхцөл/нууцлал, гарах
    content/   terms/privacy/faq (backend-ээс)
  shared/      PrimaryButton (press glow), CountdownText (pulse), LiveBadge, PriceText
```

## Дараагийн үе шат (TODO)

- Админ дэлгэцүүд (auction үүсгэх/нийтлэх, зурaг upload, цэнэглэлт хянах)
- Avatar upload (R2 presign бэлэн, image_picker нэмэх)
- FCM push мэдэгдэл
- QR-ыг зурган хэлбэрээр үзүүлэх (qr_flutter), deeplink нээх (url_launcher)
