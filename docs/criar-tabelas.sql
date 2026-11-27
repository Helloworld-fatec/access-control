-- Cria TODAS as tabelas do projeto (as 4 migrações do Prisma, em ordem).
-- Use em um banco VAZIO (ex.: no pgAdmin: Query Tool no banco, colar e executar com F5).
-- Depois, marque as migrações como aplicadas (veja docs/como-rodar.md, passo "Banco pelo pgAdmin").

-- ===== 20261010220339_init =====
-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "document" TEXT,
    "email" TEXT NOT NULL,
    "phone" TEXT,
    "passwordHash" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NfcTag" (
    "id" TEXT NOT NULL,
    "uid" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NfcTag_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FaceTemplate" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "embedding" DOUBLE PRECISION[],
    "modelVersion" TEXT NOT NULL,
    "consentAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FaceTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserPhoto" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "filePath" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL DEFAULT 'image/jpeg',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserPhoto_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Location" (
    "id" TEXT NOT NULL,
    "building" TEXT NOT NULL,
    "entrance" TEXT,
    "door" TEXT,
    "turnstile" TEXT,
    "description" TEXT,

    CONSTRAINT "Location_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Terminal" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "locationId" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "qrSecret" TEXT NOT NULL,
    "apiKeyHash" TEXT NOT NULL,
    "online" BOOLEAN NOT NULL DEFAULT false,
    "lastPresenceAt" TIMESTAMP(3),
    "lastSeenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Terminal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Authorization" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "locationId" TEXT NOT NULL,
    "startDate" DATE NOT NULL,
    "endDate" DATE NOT NULL,
    "startTime" TEXT NOT NULL,
    "endTime" TEXT NOT NULL,
    "maxUses" INTEGER,
    "usedCount" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "createdById" TEXT NOT NULL,
    "canceledAt" TIMESTAMP(3),
    "canceledById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Authorization_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AccessLog" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "terminalId" TEXT NOT NULL,
    "authorizationId" TEXT,
    "method" TEXT NOT NULL,
    "result" TEXT NOT NULL,
    "reason" TEXT,
    "nfcUid" TEXT,
    "confidence" DOUBLE PRECISION,
    "distanceMeters" DOUBLE PRECISION,
    "commandAcked" BOOLEAN,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AccessLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QrNonce" (
    "nonce" TEXT NOT NULL,
    "terminalId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "QrNonce_pkey" PRIMARY KEY ("nonce")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_document_key" ON "User"("document");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_role_active_idx" ON "User"("role", "active");

-- CreateIndex
CREATE UNIQUE INDEX "NfcTag_uid_key" ON "NfcTag"("uid");

-- CreateIndex
CREATE INDEX "NfcTag_userId_idx" ON "NfcTag"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "FaceTemplate_userId_key" ON "FaceTemplate"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "UserPhoto_userId_key" ON "UserPhoto"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Location_building_entrance_door_turnstile_key" ON "Location"("building", "entrance", "door", "turnstile");

-- CreateIndex
CREATE INDEX "Terminal_locationId_idx" ON "Terminal"("locationId");

-- CreateIndex
CREATE INDEX "Authorization_userId_locationId_status_idx" ON "Authorization"("userId", "locationId", "status");

-- CreateIndex
CREATE INDEX "Authorization_endDate_idx" ON "Authorization"("endDate");

-- CreateIndex
CREATE INDEX "AccessLog_createdAt_idx" ON "AccessLog"("createdAt");

-- CreateIndex
CREATE INDEX "AccessLog_userId_createdAt_idx" ON "AccessLog"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "AccessLog_terminalId_createdAt_idx" ON "AccessLog"("terminalId", "createdAt");

-- CreateIndex
CREATE INDEX "QrNonce_expiresAt_idx" ON "QrNonce"("expiresAt");

-- AddForeignKey
ALTER TABLE "NfcTag" ADD CONSTRAINT "NfcTag_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FaceTemplate" ADD CONSTRAINT "FaceTemplate_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserPhoto" ADD CONSTRAINT "UserPhoto_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Terminal" ADD CONSTRAINT "Terminal_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "Location"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_canceledById_fkey" FOREIGN KEY ("canceledById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessLog" ADD CONSTRAINT "AccessLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessLog" ADD CONSTRAINT "AccessLog_terminalId_fkey" FOREIGN KEY ("terminalId") REFERENCES "Terminal"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessLog" ADD CONSTRAINT "AccessLog_authorizationId_fkey" FOREIGN KEY ("authorizationId") REFERENCES "Authorization"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QrNonce" ADD CONSTRAINT "QrNonce_terminalId_fkey" FOREIGN KEY ("terminalId") REFERENCES "Terminal"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ===== 20261018000000_rename_user_table_to_users =====
-- Rename the existing table in place to preserve users and foreign-key relations.
ALTER TABLE "User" RENAME TO "users";

-- Keep Prisma's default PostgreSQL names aligned with the mapped table name.
ALTER TABLE "users" RENAME CONSTRAINT "User_pkey" TO "users_pkey";
ALTER INDEX "User_document_key" RENAME TO "users_document_key";
ALTER INDEX "User_email_key" RENAME TO "users_email_key";
ALTER INDEX "User_role_active_idx" RENAME TO "users_role_active_idx";

-- ===== 20261018010000_qr_nonce_consumed =====
ALTER TABLE "QrNonce"
ADD COLUMN "consumedAt" TIMESTAMP(3);

-- ===== 20261018020000_lowercase_model_tables =====
-- Rename existing tables in place. This preserves all rows and existing relations.
ALTER TABLE "NfcTag" RENAME TO "nfc_tags";
ALTER TABLE "FaceTemplate" RENAME TO "face_templates";
ALTER TABLE "UserPhoto" RENAME TO "user_photos";
ALTER TABLE "Location" RENAME TO "locations";
ALTER TABLE "Terminal" RENAME TO "terminals";
ALTER TABLE "Authorization" RENAME TO "authorizations";
ALTER TABLE "AccessLog" RENAME TO "access_logs";
ALTER TABLE "QrNonce" RENAME TO "qr_nonces";

-- Align primary-key and foreign-key constraint names with the new table names.
ALTER TABLE "nfc_tags" RENAME CONSTRAINT "NfcTag_pkey" TO "nfc_tags_pkey";
ALTER TABLE "nfc_tags" RENAME CONSTRAINT "NfcTag_userId_fkey" TO "nfc_tags_user_id_fkey";
ALTER TABLE "face_templates" RENAME CONSTRAINT "FaceTemplate_pkey" TO "face_templates_pkey";
ALTER TABLE "face_templates" RENAME CONSTRAINT "FaceTemplate_userId_fkey" TO "face_templates_user_id_fkey";
ALTER TABLE "user_photos" RENAME CONSTRAINT "UserPhoto_pkey" TO "user_photos_pkey";
ALTER TABLE "user_photos" RENAME CONSTRAINT "UserPhoto_userId_fkey" TO "user_photos_user_id_fkey";
ALTER TABLE "locations" RENAME CONSTRAINT "Location_pkey" TO "locations_pkey";
ALTER TABLE "terminals" RENAME CONSTRAINT "Terminal_pkey" TO "terminals_pkey";
ALTER TABLE "terminals" RENAME CONSTRAINT "Terminal_locationId_fkey" TO "terminals_location_id_fkey";
ALTER TABLE "authorizations" RENAME CONSTRAINT "Authorization_pkey" TO "authorizations_pkey";
ALTER TABLE "authorizations" RENAME CONSTRAINT "Authorization_userId_fkey" TO "authorizations_user_id_fkey";
ALTER TABLE "authorizations" RENAME CONSTRAINT "Authorization_locationId_fkey" TO "authorizations_location_id_fkey";
ALTER TABLE "authorizations" RENAME CONSTRAINT "Authorization_createdById_fkey" TO "authorizations_created_by_id_fkey";
ALTER TABLE "authorizations" RENAME CONSTRAINT "Authorization_canceledById_fkey" TO "authorizations_canceled_by_id_fkey";
ALTER TABLE "access_logs" RENAME CONSTRAINT "AccessLog_pkey" TO "access_logs_pkey";
ALTER TABLE "access_logs" RENAME CONSTRAINT "AccessLog_userId_fkey" TO "access_logs_user_id_fkey";
ALTER TABLE "access_logs" RENAME CONSTRAINT "AccessLog_terminalId_fkey" TO "access_logs_terminal_id_fkey";
ALTER TABLE "access_logs" RENAME CONSTRAINT "AccessLog_authorizationId_fkey" TO "access_logs_authorization_id_fkey";
ALTER TABLE "qr_nonces" RENAME CONSTRAINT "QrNonce_pkey" TO "qr_nonces_pkey";
ALTER TABLE "qr_nonces" RENAME CONSTRAINT "QrNonce_terminalId_fkey" TO "qr_nonces_terminal_id_fkey";

-- Rename indexes in place; no indexes are dropped or rebuilt.
ALTER INDEX "NfcTag_uid_key" RENAME TO "nfc_tags_uid_key";
ALTER INDEX "NfcTag_userId_idx" RENAME TO "nfc_tags_user_id_idx";
ALTER INDEX "FaceTemplate_userId_key" RENAME TO "face_templates_user_id_key";
ALTER INDEX "UserPhoto_userId_key" RENAME TO "user_photos_user_id_key";
ALTER INDEX "Location_building_entrance_door_turnstile_key" RENAME TO "locations_building_entrance_door_turnstile_key";
ALTER INDEX "Terminal_locationId_idx" RENAME TO "terminals_location_id_idx";
ALTER INDEX "Authorization_userId_locationId_status_idx" RENAME TO "authorizations_user_location_status_idx";
ALTER INDEX "Authorization_endDate_idx" RENAME TO "authorizations_end_date_idx";
ALTER INDEX "AccessLog_createdAt_idx" RENAME TO "access_logs_created_at_idx";
ALTER INDEX "AccessLog_userId_createdAt_idx" RENAME TO "access_logs_user_created_at_idx";
ALTER INDEX "AccessLog_terminalId_createdAt_idx" RENAME TO "access_logs_terminal_created_at_idx";
ALTER INDEX "QrNonce_expiresAt_idx" RENAME TO "qr_nonces_expires_at_idx";


