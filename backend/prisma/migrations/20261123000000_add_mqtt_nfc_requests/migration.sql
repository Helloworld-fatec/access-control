CREATE TABLE "mqtt_nfc_requests" (
    "terminalId" TEXT NOT NULL,
    "requestId" UUID NOT NULL,
    "fingerprint" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "decision" JSONB,
    CONSTRAINT "mqtt_nfc_requests_pkey" PRIMARY KEY ("terminalId", "requestId")
);

CREATE INDEX "mqtt_nfc_requests_expiresAt_idx" ON "mqtt_nfc_requests"("expiresAt");
ALTER TABLE "terminals"
    ADD COLUMN "mqttPresenceAt" TIMESTAMP(3),
    ADD COLUMN "mqttDoorState" TEXT,
    ADD COLUMN "mqttDoorStateAt" TIMESTAMP(3);

