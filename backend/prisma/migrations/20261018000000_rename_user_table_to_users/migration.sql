-- Rename the existing table in place to preserve users and foreign-key relations.
ALTER TABLE "User" RENAME TO "users";

-- Keep Prisma's default PostgreSQL names aligned with the mapped table name.
ALTER TABLE "users" RENAME CONSTRAINT "User_pkey" TO "users_pkey";
ALTER INDEX "User_document_key" RENAME TO "users_document_key";
ALTER INDEX "User_email_key" RENAME TO "users_email_key";
ALTER INDEX "User_role_active_idx" RENAME TO "users_role_active_idx";
