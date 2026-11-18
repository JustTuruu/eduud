# E-Duud backend — Spring Boot + Kafka

E-Duud-ийн backend: Java 17 / Spring Boot 3.5 + Kafka. Өмнөх NestJS хувилбарыг орлосон
(REST API, Socket.IO event-үүд нь түүнтэй ижил; NestJS-ийн код git түүхэнд бий).

Гол ялгаа нь санал (bid) боловсруулалт:

```
NestJS:  POST /bid ──► DB мөр түгжих (FOR UPDATE) ──► 7 бичилт ──► 200
Spring:  POST /bid ──► урьдчилсан шалгалт ──► Kafka `auction.bids` (key=auctionId) ──► 202 PENDING
                                                   │
                       consumer (partition бүрт 1 thread) ◄─┘
                       багцыг нэг транзакцаар боловсруулна ──► DB ──► Socket.IO (bid_placed / bid_rejected)
```

## Санал боловсруулах 2 горим (`BID_MODE`)

| Горим             | Юу хийдэг                                                                             | Хэрэглээ                         |
| ----------------- | ------------------------------------------------------------------------------------- | -------------------------------- |
| `kafka` (анхдагч) | API нь саналыг Kafka руу илгээгээд 202 буцаана. Consumer дарааллаар боловсруулна.     | Үндсэн шийдэл                    |
| `direct`          | Хүсэлтийн дотор шууд DB транзакц хийгээд 200 буцаана (queue-гүй). Kafka шаардлагагүй. | k6-аар харьцуулах суурь хувилбар |

Хоёр горим **ижил** `BidProcessor`-ийг ашигладаг тул k6-ийн үр дүнгийн ялгаа нь зөвхөн
queue-ийн нөлөө болно.

## Kafka-гийн зохиомж (тайлангийн 5-р бүлэг)

- **Topic** `auction.bids`: 12 partition (`BID_TOPIC_PARTITIONS`), key = `auctionId` →
  нэг auction-ы бүх санал нэг partition-д, FIFO дарааллаар.
- **Producer**: `acks=all`, idempotent. Broker ack ирээгүй бол хэрэглэгчид 503 буцааж
  санал зарцуулагдахгүй.
- **Consumer** (`bid-processor`): batch listener, partition тоотой тэнцүү thread. Багц
  доторх auction болон wallet-уудыг id-ийн дарааллаар нэг л удаа түгжинэ (deadlock-гүй),
  санал бүрийг санах ойд үнэлээд batch INSERT/UPDATE хийнэ.
- **Idempotency**: `bid_requests` хүснэгт (PK = API дээр үүссэн `bidId`). Давхар ирсэн
  message алгасагдана, татгалзсан санал ч дахин үнэлэгдэхгүй.
- **Алдаа**: 1с → 4с → 16с хоцролттой 3 удаа retry → `auction.bids.DLT`. Retry нь
  blocking тул partition доторх дараалал алдагдахгүй. Задрахгүй message шууд DLT руу.
- **Ялагч тодруулах**: auction хаагдахаас өмнө partition-ийн lag = 0 болохыг шалгана
  (`PartitionLagChecker`), API хүлээн авсан ч боловсруулагдаагүй санал алдагдахгүй.
- **Эрэмбэ**: санал бүрт API хүлээн авсан серверийн цаг (`received_at`) тэмдэглэгдэж,
  хугацааны шалгалт түүгээр хийгдэнэ (BR-13). Kafka-гийн partition/offset `bids`-д
  хадгалагдана (BR-12).

## Ажиллуулах

```bash
docker compose up -d postgres kafka          # Postgres :55432, Kafka :9092 (Kafka UI: docker compose up -d kafka-ui → :8090)
mvn package -DskipTests
java -jar target/eduud-backend-spring-0.1.0.jar --seed        # багц, админ (99000000 / admin1234), контент
java -jar target/eduud-backend-spring-0.1.0.jar               # API :3000, Socket.IO :3001
```

Load test-ийн өгөгдөл (утас `90100000`…, нууц үг `loadtest123`):

```bash
java -jar target/eduud-backend-spring-0.1.0.jar --seed-loadtest --users=500 --tokens=1000 --auctions=12
```

Direct горим: `BID_MODE=direct java -jar target/eduud-backend-spring-0.1.0.jar`

> Анхаар: апп ажиллаж байх үед `mvn package` хийж jar-ыг солих хэрэггүй — эхлээд
> зогсооно.

### Minikube (Kubernetes)

`k8s/` дотор Postgres, Kafka (KRaft), backend, seed Job-ийн manifest бий.

```bash
brew install minikube
./k8s/minikube.sh          # minikube асааж, image build хийж, deploy + seed
./k8s/minikube.sh build    # код өөрчилсний дараа: image дахин build + backend restart
./k8s/minikube.sh down     # eduud namespace-ийг устгана (DB өгөгдөл мөн устна)

kubectl -n eduud get pods
kubectl -n eduud logs -f deploy/backend
kubectl -n eduud port-forward svc/backend 3000:3000 3001:3001   # → localhost:3000 / :3001
```

macOS (docker driver) дээр `minikube ip`-ийн NodePort (30000/30001) руу шууд хандах
боломжгүй тул `port-forward` ашиглана. Backend нь 1 replica — Socket.IO room нь pod-ын
санах ойд байдаг тул олон replica болгоход нэмэлт ажил хэрэгтэй.

### Flutter

Socket.IO нь тусдаа портон (3001) дээр ажилладаг (netty-socketio):

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000 --dart-define=SOCKET_URL=http://10.0.2.2:3001
```

`SOCKET_URL` өгөхгүй бол `API_URL`-ийн портыг 3001 болгож ашиглана.

## Орчны хувьсагч

NestJS-ийн `.env`-тэй ижил нэртэй: `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`,
`JWT_ACCESS_TTL_SEC`, `OTP_PROVIDER`, `VERIFYMN_*`, `WIRE_*`, `R2_*`,
`ORDER_PAY_DEADLINE_HOURS`, `PORT`. Ижил `JWT_ACCESS_SECRET` (≥ 32 тэмдэгт) ашиглавал
хоёр backend нэг нэгнийхээ токенийг хүлээн авна.

Шинэ хувьсагчид:

| Хувьсагч                             | Анхдагч                                   | Тайлбар                                |
| ------------------------------------ | ----------------------------------------- | -------------------------------------- |
| `DB_URL` / `DB_USER` / `DB_PASSWORD` | `jdbc:postgresql://localhost:55432/eduud` | JDBC холболт                           |
| `DB_POOL_SIZE`                       | 20                                        | Hikari pool                            |
| `KAFKA_BOOTSTRAP`                    | `localhost:9092`                          |                                        |
| `BID_MODE`                           | `kafka`                                   | `kafka` \| `direct`                    |
| `BID_TOPIC_PARTITIONS`               | 12                                        | Туршилтад 1, 3, 6, 12                  |
| `BID_CONSUMER_CONCURRENCY`           | 12                                        | Partition тоотой тэнцүү байлгана       |
| `BID_MAX_POLL_RECORDS`               | 500                                       | Нэг багцын дээд хэмжээ                 |
| `SOCKET_PORT`                        | 3001                                      | Socket.IO                              |
| `FLYWAY_BASELINE_VERSION`            | 0                                         | Prisma-гаар migrate хийсэн DB дээр `2` |

## Хэмжилт

`GET /actuator/prometheus`:

- `bids_processed_total{result=accepted|rejected|duplicate}`
- `bids_end_to_end_seconds` — API хүлээн авснаас DB-д бичигдэх хүртэл (p50/p95/p99)
- `bids_batch_size` — consumer-ийн багцын хэмжээ
- `kafka_consumer_*` (lag гэх мэт), `hikaricp_*`, `http_server_requests_*`, JVM

## NestJS-ээс ялгаатай зүйлс

|                          | NestJS                             | Spring Boot                                                                         |
| ------------------------ | ---------------------------------- | ----------------------------------------------------------------------------------- |
| `POST /auctions/:id/bid` | 200 `{ok, price, endsAt, balance}` | kafka: 202 `{ok, status: "PENDING", bidId}`; direct: 200 (ижил)                     |
| Татгалзсан санал (kafka) | 400                                | Урьдчилсан шалгалтад баригдвал 400, consumer татгалзвал `bid_rejected` socket event |
| Хугацаат ажил            | pg-boss (санал бүрт job)           | `AuctionScheduler` — DB-г 250 мс тутам шалгана                                      |
| Socket.IO порт           | API-тай ижил                       | `SOCKET_PORT` (3001)                                                                |
| DB                       | Prisma migrations                  | Flyway (V1, V2 = Prisma-тай ижил; V3 = `bid_requests` + `bids`-ийн нэмэлт баганууд) |

Flutter апп `bid_placed`/`wallet_updated` event-ээр шинэчлэгддэг, bid-ийн хариуны
body-г ашигладаггүй тул 202 хариу аппыг эвдэхгүй.
