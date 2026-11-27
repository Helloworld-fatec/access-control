ALTER TABLE "mqtt_door_commands"
    ALTER COLUMN "accessLogId" DROP NOT NULL,
    ADD COLUMN "checkoutVisitId" UUID,
    ADD CONSTRAINT "mqtt_door_commands_checkoutVisitId_fkey"
        FOREIGN KEY ("checkoutVisitId") REFERENCES "visits"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT "mqtt_door_commands_source_check"
        CHECK (("accessLogId" IS NULL) <> ("checkoutVisitId" IS NULL));

CREATE UNIQUE INDEX "mqtt_door_commands_checkoutVisitId_key"
    ON "mqtt_door_commands"("checkoutVisitId");
