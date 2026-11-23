import { randomUUID } from "node:crypto";
import { create } from "qrcode";
import { issueQrToken, qrRefreshSeconds } from "./qr-token.service.js";

export async function issueOledQr(terminalId: string, requestId: string) {
  const { token, issuedAt, expiresAt } = await issueQrToken(terminalId, true);
  const { modules } = create([{ data: token, mode: "alphanumeric" }], {
    version: 1, errorCorrectionLevel: "M",
  });
  const bitmap = Buffer.alloc(Math.ceil(modules.data.length / 8));
  modules.data.forEach((dark, index) => {
    if (dark) bitmap[index >> 3]! |= 1 << (7 - (index & 7));
  });
  return {
    schemaVersion: 1,
    terminalId,
    eventId: randomUUID(),
    requestId,
    occurredAt: issuedAt.toISOString(),
    expiresAt: expiresAt.toISOString(),
    refreshAfterSeconds: qrRefreshSeconds,
    bitmap: bitmap.toString("hex"),
  };
}
