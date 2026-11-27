CREATE TABLE "nfc_credentials" (
    "userId" TEXT NOT NULL,
    "codeHex" VARCHAR(6) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "nfc_credentials_pkey" PRIMARY KEY ("userId"),
    CONSTRAINT "nfc_credentials_code_hex_check" CHECK ("codeHex" ~ '^[0-9A-F]{6}$'),
    CONSTRAINT "nfc_credentials_user_id_fkey" FOREIGN KEY ("userId")
        REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "nfc_credentials_codeHex_key" ON "nfc_credentials"("codeHex");
