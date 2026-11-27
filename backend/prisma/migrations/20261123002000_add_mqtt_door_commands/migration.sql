CREATE TABLE "mqtt_door_commands" (
    "id" UUID NOT NULL,
    "accessLogId" TEXT NOT NULL,
    "terminalId" TEXT NOT NULL,
    "issuedAt" TIMESTAMP(3) NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "ackResult" TEXT,
    "ackAt" TIMESTAMP(3),
    CONSTRAINT "mqtt_door_commands_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "mqtt_door_commands_accessLogId_fkey" FOREIGN KEY ("accessLogId")
        REFERENCES "access_logs"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "mqtt_door_commands_terminalId_fkey" FOREIGN KEY ("terminalId")
        REFERENCES "terminals"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "mqtt_door_commands_accessLogId_key" ON "mqtt_door_commands"("accessLogId");
CREATE INDEX "mqtt_door_commands_ackResult_expiresAt_idx" ON "mqtt_door_commands"("ackResult", "expiresAt");
