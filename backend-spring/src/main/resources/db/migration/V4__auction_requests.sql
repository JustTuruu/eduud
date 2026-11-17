-- Дуудлага худалдаа зохион байгуулах хүсэлт (UC-05)
CREATE TYPE "AuctionRequestStatus" AS ENUM ('draft', 'pending', 'reviewing', 'info_requested', 'approved', 'rejected', 'cancelled');

CREATE TABLE "auction_requests" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "category" TEXT,
    "start_price" INTEGER CHECK ("start_price" IS NULL OR "start_price" >= 0),
    "preferred_date" TEXT,
    "other_info" TEXT,
    "status" "AuctionRequestStatus" NOT NULL DEFAULT 'pending',
    "admin_note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT "auction_requests_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "auction_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "auction_requests_user_id_created_at_idx" ON "auction_requests"("user_id", "created_at");
CREATE INDEX "auction_requests_status_created_at_idx" ON "auction_requests"("status", "created_at");
