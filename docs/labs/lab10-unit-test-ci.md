# Lab 10 — Unit test бичих, CI pipeline-д холбох

## 1. Сонгосон функцүүд ба шалтгаан

| Функц | Файл | Яагаад |
|---|---|---|
| `AuctionLogic.validateBid`, `AuctionLogic.computeNewEndsAt` | `backend-spring/src/main/java/mn/eduud/auctions/AuctionLogic.java` | Цэвэр логик (DB-ээс хараат бус), bid-ийн хүлээн авах дүрэм ба soft-close сунгалт. Хязгаарын тохиолдол (яг дуусах мөч, hardCloseAt, маш том утга) олон. |
| `PaymentsService.settle` | `backend-spring/src/main/java/mn/eduud/payments/PaymentsService.java` | Гадаад хамаарал (DB, транзакц, Socket.IO) бүхий idempotent функц. `UPDATE ... WHERE status='pending'` guard нь token давхар нэмэгдэхээс сэргийлдэг — үүнийг DB-гүйгээр Mockito-оор шалгана. |

Бүх тест AAA (Arrange-Act-Assert) бүтэцтэй, `// Arrange`, `// Act`, `// Assert` тайлбараар тэмдэглэсэн.

## 2. Тестүүдийн жагсаалт

Файл: `AuctionLogicEdgeTest.java` (`backend-spring/src/test/java/mn/eduud/auctions/`)

| Тест | Төрөл | Юуг шалгах вэ |
|---|---|---|
| `validateBid_otherUserThanLastBidder_isAccepted` | normal | Сүүлийн bidder биш өөр хэрэглэгчийн санал зөвшөөрөгдөнө |
| `computeNewEndsAt_insideSoftClose_extendsFromNow` | normal | Soft-close цонхонд санал ирвэл `now + extendSec` хүртэл сунгана |
| `validateBid_noLastBidder_nullIsAccepted` | edge (null) | `lastBidderId = null` (анхны санал) үед алдаагүй |
| `validateBid_oneMillisecondBeforeEnd_isAccepted` | edge (хязгаар) | Дуусахаас 1 мс өмнөх санал зөвшөөрөгдөнө |
| `validateBid_exactlyAtStart_isNotRejectedAsNotStarted` | edge (хязгаар) | `now == startsAt` үед NOT_STARTED биш |
| `computeNewEndsAt_exactlyAtSoftCloseBoundary_extends` | edge (хязгаар) | Үлдсэн хугацаа яг `softCloseSec` үед сунгана |
| `computeNewEndsAt_veryLargeExtendSec_cappedByHardClose` | edge (маш том тоо) | `extendSec = Integer.MAX_VALUE` үед `hardCloseAt`-аас хэтрэхгүй |
| `computeNewEndsAt_alreadyPastEnd_negativeTimeLeftStillNeverShortens` | edge (сөрөг) | Үлдсэн хугацаа сөрөг үед `endsAt`-аас богиносохгүй |

Файл: `PaymentsServiceTest.java` (`backend-spring/src/test/java/mn/eduud/payments/`) — `JdbcClient` (`RETURNS_DEEP_STUBS`), `TransactionTemplate`, `RealtimeGateway`, `WireService`, `Rows`-ийг Mockito-оор орлуулсан.

| Тест | Төрөл | Юуг шалгах вэ |
|---|---|---|
| `settle_alreadyPaid_updateAffectsZeroRows_noSideEffects` | mock | UPDATE 0 мөр өөрчлөхөд wallet/token_transactions рүү хандахгүй, event явахгүй |
| `settle_topupPending_creditsWalletAndEmitsBalance` | mock | Topup амжилттай үед шинэ үлдэгдэлтэй `wallet_updated` event явна |
| `settle_calledTwice_secondCallDoesNotEmitAgain` | mock | Давхар дуудахад event зөвхөн нэг удаа явна (idempotency) |

Нийт шинэ тест: 11.

## 3. Локал дээр ажиллуулах

```bash
cd backend-spring && mvn -q test          # backend (Postgres/Kafka шаардахгүй)
mvn -q test -Dtest=AuctionLogicEdgeTest   # ганц класс
cd ../app && flutter test                 # Flutter апп
```

## 4. CI pipeline

Файл: `.github/workflows/ci.yml`. `main` дээрх push болон pull_request үед ажиллана.

- `backend` job: ubuntu-latest, `actions/setup-java@v4` (temurin 17, maven cache), `mvn -B test` (`backend-spring` дотор), surefire тайланг artifact болгон хадгална.
- `app` job: `subosito/flutter-action@v2` (stable, cache), `flutter pub get`, `flutter test` (`app` дотор).

Хоёр job зэрэг ажиллана; аль нэг нь унавал commit/PR-д улаан тэмдэг гарна.

CI амжилттай болсон screenshot: _(энд screenshot оруулна)_

## 5. Алхам 8 — "санаатай унагаах"

Зорилго: CI тест унавал алдааг барьж байгааг харуулах. `main`-ийг эвдэхгүйн тулд тусдаа branch дээр хийнэ.

```bash
git checkout -b lab10-broken-test
# Жишээ: AuctionLogic.validateBid дахь нөхцлийг санаатай буруу болгох
#   if (!now.isBefore(a.endsAt)) ...  ->  if (now.isAfter(a.endsAt)) ...
# эсвэл тестийн хүлээгдэж буй утгыг өөрчлөх
git commit -am "test: CI унагаах туршилт"
git push -u origin lab10-broken-test
```

GitHub дээр `lab10-broken-test` -> `main` Pull Request нээнэ. `backend` job улаан болж, `AuctionLogicEdgeTest` унасан тайланг харуулна (screenshot авна). Дараа нь өөрчлөлтийг буцааж (`git revert` эсвэл засаад push) CI ногоон болохыг харуулж, PR-ийг merge хийхгүйгээр хаана.

Screenshot (улаан CI): _(энд screenshot оруулна)_
Screenshot (засварын дараах ногоон CI): _(энд screenshot оруулна)_
