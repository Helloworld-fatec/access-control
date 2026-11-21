ALTER TABLE "access_logs" ADD COLUMN "faceAttemptId" UUID;

CREATE UNIQUE INDEX "access_logs_terminal_face_attempt_key"
ON "access_logs"("terminalId", "faceAttemptId");
