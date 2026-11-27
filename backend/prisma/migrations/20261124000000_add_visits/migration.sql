CREATE TYPE "VisitCheckoutType" AS ENUM ('SIMPLE', 'POKEMON');

CREATE TABLE "visits" (
    "id" UUID NOT NULL,
    "userId" TEXT,
    "locationId" TEXT NOT NULL,
    "entryTerminalId" TEXT NOT NULL,
    "entryLogId" TEXT NOT NULL,
    "enteredAt" TIMESTAMP(3) NOT NULL,
    "exitedAt" TIMESTAMP(3),
    "checkoutType" "VisitCheckoutType",
    "checkedOutById" TEXT,
    CONSTRAINT "visits_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "visits_userId_fkey"
        FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "visits_checkedOutById_fkey"
        FOREIGN KEY ("checkedOutById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "visits_locationId_fkey"
        FOREIGN KEY ("locationId") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "visits_entryTerminalId_fkey"
        FOREIGN KEY ("entryTerminalId") REFERENCES "terminals"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "visits_entryLogId_fkey"
        FOREIGN KEY ("entryLogId") REFERENCES "access_logs"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "visits_checkout_state_check"
        CHECK (
            ("exitedAt" IS NULL AND "checkoutType" IS NULL AND "checkedOutById" IS NULL)
            OR ("exitedAt" IS NOT NULL AND "checkoutType" IS NOT NULL AND "exitedAt" >= "enteredAt")
        )
);

CREATE UNIQUE INDEX "visits_entryLogId_key" ON "visits"("entryLogId");
CREATE UNIQUE INDEX "visits_one_open_per_user_location" ON "visits"("userId", "locationId")
    WHERE "exitedAt" IS NULL AND "userId" IS NOT NULL;
CREATE INDEX "visits_exitedAt_enteredAt_idx" ON "visits"("exitedAt", "enteredAt");
CREATE INDEX "visits_locationId_exitedAt_enteredAt_idx"
    ON "visits"("locationId", "exitedAt", "enteredAt");
