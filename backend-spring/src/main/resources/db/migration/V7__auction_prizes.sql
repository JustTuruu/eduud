-- 2/3-р байрны нэмэлт шагнал (админ тохируулна): токен эсвэл бараа.
-- Ledger-т шагналын токенийг 'prize' төрлөөр бүртгэнэ.
ALTER TYPE "TokenTxType" ADD VALUE IF NOT EXISTS 'prize';

CREATE TABLE auction_prizes (
    auction_id      TEXT     NOT NULL REFERENCES auctions (id) ON DELETE CASCADE,
    place           SMALLINT NOT NULL CHECK (place IN (2, 3)),
    kind            TEXT     NOT NULL CHECK (kind IN ('tokens', 'item')),
    tokens          INTEGER  CHECK (tokens IS NULL OR (tokens >= 1 AND tokens <= 100000)),
    title           TEXT,
    awarded_user_id TEXT     REFERENCES users (id),
    awarded_at      TIMESTAMP(3),
    order_id        TEXT     REFERENCES orders (id),
    PRIMARY KEY (auction_id, place),
    CHECK ((kind = 'tokens' AND tokens IS NOT NULL) OR (kind = 'item' AND title IS NOT NULL))
);

-- Барааны шагнал нь 0₮-ийн төлөгдсөн захиалга болж, нэг дуудлагад үндсэн (ялагчийн)
-- захиалгаас гадна 2/3-р байрных нэмж үүснэ. Иймд auction_id-ийн unique-ийг сулруулна.
ALTER TABLE orders ADD COLUMN prize_place SMALLINT;
ALTER TABLE orders ADD COLUMN prize_title TEXT;
DROP INDEX "orders_auction_id_key";
CREATE UNIQUE INDEX orders_auction_main_key ON orders (auction_id) WHERE prize_place IS NULL;
CREATE UNIQUE INDEX orders_auction_prize_key ON orders (auction_id, prize_place) WHERE prize_place IS NOT NULL;
