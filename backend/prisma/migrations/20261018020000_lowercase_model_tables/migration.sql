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

