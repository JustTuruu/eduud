---
version: 1
slug: "app-lib-features-home-home-screen-dart"
primary_target: "app/lib/features/home/home_screen.dart"
related_targets: ["app/lib/shared/app_nav_bar.dart","app/lib/core/router.dart"]
---

# Surface: бүх апп (Flutter, утас + web) — цэвэрхэн iOS-native

Mode: operate. Хэрэглэгч 2026-11-18-нд "Now Playing" (ambient өнгөт бүдэг дэвсгэр, чавга, шүрэн) дизайныг бүрэн татгалзсан: "хэн ч ийм дизайн хэрэглэхгүй, маш гоё цэвэрхэн байлгамаар байна; Apple Music-ийн зөвхөн footer (tab bar)-ыг л хэлсэн, дотор content-ийг биш". Now Playing ба Ice Night хоёулаа анти-лавлагаа.

## Direction contract

FORM: user-pinned (roll хэрэглээгүй) — iOS-native цэвэрхэн апп + iOS 26 Apple Music "Liquid Glass" tab bar. seed: none (user-pinned)

THESIS: Агуулга нь өөрөө ярина: барааны зураг, үнэ, үлдсэн хугацаа. Чимэглэл, gradient, glow, өнгөт бүдэг талбар огт байхгүй; App Store / Settings шиг хэрэглэгч аль хэдийн мэддэг цэвэр бүтэц.

OWN-WORLD: Системийн theme (утасны light/dark-ыг дагана). Light: дэвсгэр #F2F2F7 (grouped) / #FFFFFF, карт #FFFFFF, текст #000000, secondary #3C3C43 @60%, separator #3C3C43 @29% (0.5px). Dark: дэвсгэр #000000, карт #1C1C1E, elevated #2C2C2E, текст #FFFFFF, secondary #EBEBF5 @60%. Accent ногоон: light #34C759 / dark #30D158 (товч, идэвхтэй таб, progress). Улаан зөвхөн алдаа/сүүлийн секунд (#FF3B30/#FF453A). Фонт: платформын системийн (iOS SF Pro; Android Roboto; web system-ui) — том гарчиг 34/700, гарчиг 22/700, body 17/400, footnote 13. Булан: карт 16–20, товч 14 эсвэл бүтэн pill. Сүүдэр бараг үгүй (light-д маш зөөлөн). Icon: SF Symbols маягийн filled (CupertinoIcons) tab bar-д, бусад газар outline.

FIRST VIEWPORT (Нүүр): iOS large title "Нүүр" + баруун дээд буланд "128 эрх" жижиг товч. Доор нь явагдаж буй дуудлага худалдааны том карт (зураг 1:1 дугуй булантай, нэр, тэргүүлж буй хүн, үнэ том, нимгэн progress + үлдсэн хугацаа, ногоон "Санал өгөх" товч); олон бол хажуу тийш гүйлгэнэ. Доош: "Удахгүй эхлэх", "Дууссан" хэвтээ мөрүүд (App Store-ын мөр шиг). Хамгийн доор хөвөгч шилэн tab bar.

SIGNATURE: Tab bar — Apple Music iOS 26 Liquid Glass: хөвөгч том капсул (blur + бага зэрэг тунгалаг материал, нимгэн гэрэлтсэн хүрээ, зөөлөн сүүдэр), filled icon + доор нь шошго, идэвхтэй таб нь капсул дотор арай цайвар шилэн pill дээр ногоон icon/шошготой; pill spring-ээр гулсана. Табууд: Нүүр, Хүсэлт, Профайл.

STORY: Нээмэгц юу явагдаж байгаа, хэд үлдсэн, хэдэн төгрөг вэ гэдгийг шууд уншина → нэг товчоор санал өгнө. Бусад дэлгэц iOS Settings/App Store шиг танил: grouped list, том гарчиг, ойлгомжтой товч.

RISK: Хэт "default" болж, брэнд алга болох — брэнд нь ногоон accent, цэвэр зураглал, нарийн хэмнэл, tab bar-ын чанараар л илэрнэ; нэмэлт чимэглэл нэмэхгүй.
