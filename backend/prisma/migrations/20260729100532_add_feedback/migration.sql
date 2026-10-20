-- CreateEnum
CREATE TYPE "FeedbackType" AS ENUM ('bug', 'idea', 'improvement', 'complaint', 'suggestion', 'praise', 'other');

-- CreateEnum
CREATE TYPE "FeedbackCategory" AS ENUM ('design', 'ux', 'performance', 'reliability', 'usability', 'content', 'billing', 'general');

-- CreateEnum
CREATE TYPE "FeedbackStatus" AS ENUM ('open', 'reviewing', 'resolved', 'closed');

-- CreateTable
CREATE TABLE "feedback" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "type" "FeedbackType" NOT NULL,
    "category" "FeedbackCategory" NOT NULL,
    "message" TEXT NOT NULL,
    "app_version" TEXT,
    "platform" TEXT,
    "status" "FeedbackStatus" NOT NULL DEFAULT 'open',
    "admin_note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "feedback_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "feedback_user_id_created_at_idx" ON "feedback"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "feedback_status_created_at_idx" ON "feedback"("status", "created_at");

-- AddForeignKey
ALTER TABLE "feedback" ADD CONSTRAINT "feedback_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
