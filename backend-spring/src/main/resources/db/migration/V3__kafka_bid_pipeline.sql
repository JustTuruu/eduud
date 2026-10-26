-- Kafka-аар дамжих саналын боловсруулалтад хэрэгтэй нэмэлтүүд.
-- NestJS (Prisma) backend-тэй нэг DB хуваалцаж болно: шинэ баганууд nullable,
-- шинэ хүснэгтийг Prisma мэдэхгүй ч ажиллагаанд нөлөөлөхгүй.

-- Санал хэзээ API-д хүлээн авагдсан (эрэмбийн эх сурвалж, BR-13) ба
-- Kafka дахь байрлал (дарааллын нотолгоо, BR-12).
ALTER TABLE "bids" ADD COLUMN "received_at" TIMESTAMP(3);
ALTER TABLE "bids" ADD COLUMN "kafka_partition" INTEGER;
ALTER TABLE "bids" ADD COLUMN "kafka_offset" BIGINT;

-- Боловсруулсан message бүрийн бүртгэл (FR-21, FR-23).
-- bid_id нь API дээр үүссэн UUID: давхар ирсэн message-ийг PK-аар таньж алгасна.
-- Татгалзсан саналууд ч энд бичигдэх тул дахин ирэхэд үр дүн нь өөрчлөгдөхгүй.
CREATE TABLE "bid_requests" (
    "bid_id"          TEXT NOT NULL,
    "auction_id"      TEXT NOT NULL,
    "user_id"         TEXT NOT NULL,
    "status"          TEXT NOT NULL,          -- ACCEPTED | REJECTED
    "reason"          TEXT,                   -- NOT_LIVE, NO_TOKENS ...
    "received_at"     TIMESTAMP(3) NOT NULL,
    "processed_at"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "kafka_partition" INTEGER,
    "kafka_offset"    BIGINT,

    CONSTRAINT "bid_requests_pkey" PRIMARY KEY ("bid_id")
);

CREATE INDEX "bid_requests_auction_id_processed_at_idx" ON "bid_requests"("auction_id", "processed_at");
CREATE INDEX "bid_requests_user_id_processed_at_idx" ON "bid_requests"("user_id", "processed_at");
