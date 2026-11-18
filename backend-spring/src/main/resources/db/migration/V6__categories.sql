-- Дуудлага худалдааны ангилал
CREATE TABLE "categories" (
    "id"         TEXT NOT NULL,
    "name"       TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "active"     BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "categories_name_key" UNIQUE ("name")
);

INSERT INTO "categories" ("id", "name", "sort_order") VALUES
    (gen_random_uuid()::text, 'Электроник', 1),
    (gen_random_uuid()::text, 'Гэр ахуй', 2),
    (gen_random_uuid()::text, 'Хувцас', 3),
    (gen_random_uuid()::text, 'Тээврийн хэрэгсэл', 4),
    (gen_random_uuid()::text, 'Бусад', 99);

ALTER TABLE "auctions" ADD COLUMN "category_id" TEXT REFERENCES "categories"("id") ON DELETE SET NULL;
CREATE INDEX "auctions_category_id_idx" ON "auctions"("category_id");
