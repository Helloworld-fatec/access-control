ALTER TABLE "nfc_credentials" ADD COLUMN "tagId" TEXT;
CREATE UNIQUE INDEX "nfc_credentials_tagId_key" ON "nfc_credentials"("tagId");
ALTER TABLE "nfc_credentials" ADD CONSTRAINT "nfc_credentials_tagId_fkey"
    FOREIGN KEY ("tagId") REFERENCES "nfc_tags"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "nfc_enrollments" (
    "id" UUID NOT NULL,
    "userId" TEXT NOT NULL,
    "terminalId" TEXT NOT NULL,
    "expectedUid" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "nfc_enrollments_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "nfc_enrollments_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "nfc_enrollments_terminalId_fkey" FOREIGN KEY ("terminalId") REFERENCES "terminals"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "nfc_enrollments_userId_createdAt_idx" ON "nfc_enrollments"("userId", "createdAt");
CREATE UNIQUE INDEX "nfc_enrollments_one_pending_per_terminal" ON "nfc_enrollments"("terminalId")
    WHERE "status" = 'PENDING';
