# Backend сайжруулалтын жагсаалт

Код уншиж хийсэн шинжилгээн дээр үндэслэсэн (2026-11-16). Load test-ээр хараахан
баталгаажаагүй — хэрэгжүүлэхээс өмнө/дараа k6-аар хэмжинэ. Хийгдсэн зүйлийг `[x]` болгоно.

## Тэргүүлэх 3 алхам

- [ ] **A. Auction хаахыг Kafka message болгох** (`CLOSE`, key = auctionId)
- [ ] **B. Socket event-үүдийг багцаар нэгтгэх**
- [ ] **C. `linger.ms` болон DB pool тохируулах**

---

## 1. Ачааллын эрсдэлтэй цэгүүд (hot spot)

### 1.1 Socket.IO fan-out — хамгийн том эрсдэл → алхам B
- Байршил: `BidProcessor.afterCommit` (`backend-spring/.../auctions/BidProcessor.java`)
- Асуудал: багц дахь accepted bid бүрт `bid_placed` (+`auction_extended`, `outbid`) бүх
  room руу явна. 1000 bid/с × 1000 үзэгч ≈ 1 сая message/с, нэг pod дээр.
- Засвар: багц бүрт auction тус бүрийн **сүүлийн төлвийг** (`price`, `endsAt`, `bidCount`,
  сүүлийн bidder) нэг л удаа илгээх. `outbid`-ыг багц доторх эцсийн байдлаар тооцох.

### 1.2 DB connection pool өлсөх → алхам C
- Байршил: `application.yml` — `DB_POOL_SIZE=20`, `connection-timeout: 2000`
- Асуудал: 12 consumer thread + 200 tomcat thread (`BidService.precheck`, list/detail) +
  scheduler нэг 20-ийн pool хуваалцана → 2с-ийн дараа 500.
- Засвар: pool-ийг 40–50 болгох (Postgres `max_connections=200`), эсвэл consumer/API
  тусдаа pool.

### 1.3 Scheduler Kafka AdminClient дээр гацах → алхам A шийднэ
- Байршил: `AuctionScheduler.tick` → `PartitionLagChecker.lag`
- Асуудал: дуусах auction бүрт 2 AdminClient дуудлага (тус бүр 3с timeout), нэг thread дээр
  дараалан. Kafka удаашрахад tick 50 × 6с хүртэл гацаж, startDue/expireOrders зогсоно.
- Түр засвар: tick-д group offset-ийг нэг удаа татаж хуваалцах, timeout багасгах.

### 1.4 `orders(status, pay_deadline)` index байхгүй
- Байршил: `AuctionsService.expireOrders` — 250мс тутам full scan UPDATE.
- Засвар: шинэ Flyway migration `V4__orders_expire_idx.sql`.

### 1.5 Hot auction = 1 partition = 1 thread
- Санаатай зохиомж (FIFO). Доорх 2.4-ийг үз.

---

## 2. Kafka-гийн сул талууд ба сайжруулалт

### 2.1 Бага ачаалал дахь latency
- `linger.ms` 5 → 0/1 (алхам C).
- Апп-д optimistic UI: 202 ирмэгц "илгээгдлээ" харуулж, socket event-ээр баталгаажуулна.
- `bids_end_to_end_seconds`-ээр хэмжиж тайланд оруулна.

### 2.2 Ажиллуулах нарийн төвөгтэй байдал
- KRaft — аль хэдийн ✅
- Redpanda (Kafka API-тай нийцтэй, нэг binary) эсвэл managed Kafka / Strimzi.
- Grafana dashboard + alert: consumer lag, DLT-д message орох.
- DLT replay admin endpoint (DLT → `auction.bids` руу буцааж илгээх).

### 2.3 Latency — алхам A
- Scheduler auction-ыг DB-ээс шууд хаахын оронд `CLOSE` message-ийг ижил partition руу
  илгээнэ → өмнөх bid бүр заавал түрүүлж боловсрогдоно.
  - `PartitionLagChecker`, AdminClient, 30с хүлээлт хэрэггүй болно (1.3 арилна).
  - Дуусах агшинд bid алдагдах асуудал (`direct` горимын NOT_LIVE race) зарчмаараа байхгүй.
- Үр дүнд нь auction-ы төлвийг зөвхөн consumer өөрчилнө → санах ойд барьж, багц бүрт
  `SELECT ... FOR UPDATE` хийхгүй болно.
  - Нөхцөл: `AdminController`-ийн cancel/publish мөн Kafka-аар дамжих эсвэл кэш цэвэрлэх.
  - Wallet-ыг санах ойд барихгүй (нэг хэрэглэгч олон partition-д bid хийдэг) — DB түгжээтэй хэвээр.
- `BidService.precheck`-ийг socket event-ээр шинэчлэгддэг санах ойн кэшээс унших
  (эцсийн шийдвэр consumer-т тул хоцорсон кэш аюулгүй).

### 2.4 Hot auction-ы дараалсан хязгаар
Bid бүр өмнөх төлвөөс хамаардаг тул зэрэгцүүлэх боломжгүй (бодлогын мөн чанар).
Serial хэсгийг жижигрүүлэх:
- Санах ойд үнэлэх (2.3) → хязгаар нь зөвхөн DB бичилт.
- Bid бүрт 3 INSERT (`bids`, `token_transactions`, `bid_requests`) → accepted-ийг `bids`-ийн
  unique `bid_id`-аар хамгаалж, `bid_requests`-д зөвхөн rejected бичих.
- Hot auction-д custom partitioner-ээр тусдаа partition (noisy neighbor арилгах).
- Хэрэглэгч бүрт rate limit (ж: 300мс-д 1 bid) — тэргүүлж буй хэрэглэгч дахин санал өгөх боломжтой болсон (`ALREADY_LAST_BIDDER` дүрэм хасагдсан) тул хязгаарлалт байхгүй.

---

## 3. Бусад анхаарах
- `bids`, `token_transactions`, `bid_requests` цэвэрлэгддэггүй — удаан хугацаанд өснө
  (archive/partition хүснэгт).
- Socket.IO room pod-ын санах ойд → олон replica болгоход Redis adapter гэх мэт хэрэгтэй.

## 4. Тайлан / хамгаалалт
- "Хамгийн оновчтой" биш, "тавьсан шаардлагад (FIFO, bid алдагдахгүй, burst, audit,
  өргөтгөл) тохирсон, хэмжилтээр нотлогдсон" гэж томъёолох.
- `direct` vs `kafka`-г ижил k6 сценариор: p95/p99 latency, 500/503 хувь, throughput,
  дуусах агшинд татгалзагдсан bid-ийн тоо.
