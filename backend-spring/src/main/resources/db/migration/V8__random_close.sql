-- Санамсаргүй хаалтын цонх (candle auction): хаагдахаас өмнөх сүүлийн N секундэд
-- дуудлага нууц санамсаргүй агшинд дуусна (сүүлийн секундэд саналаар давах тактикаас сэргийлнэ).

-- Санамсаргүй хаалтын үргэлжлэх хугацаа (сек); NULL/0 = идэвхгүй
ALTER TABLE "auctions" ADD COLUMN "random_close_sec" INTEGER;

-- Санамсаргүй цонх эхлэх агшин (нийтэд ил) — auction эхлэхэд тооцоологдоно
ALTER TABLE "auctions" ADD COLUMN "random_close_from" TIMESTAMP(3);

-- НУУЦ: бодит хаагдах агшин. Live байх хугацаанд API/socket-оор хэзээ ч гаргахгүй.
ALTER TABLE "auctions" ADD COLUMN "secret_close_at" TIMESTAMP(3);
