import { createHash, randomBytes } from "node:crypto";
import { prisma } from "../config/prisma.js";

export const qrRefreshSeconds = 10;
const qrTtlSeconds = 20;

export const hashQrToken = (token: string) => createHash("sha256").update(token).digest("hex");

export async function issueQrToken(terminalId: string, compact = false) {
  // 96 bits em base 36, com prefixo para distinguir o QR compacto no scanner.
  const token = compact
    ? "Q" + BigInt(`0x${randomBytes(12).toString("hex")}`).toString(36).toUpperCase().padStart(19, "0")
    : randomBytes(32).toString("base64url");
  const issuedAt = new Date();
  const expiresAt = new Date(issuedAt.getTime() + qrTtlSeconds * 1000);
  await prisma.qrnonce.create({
    data: { nonce: hashQrToken(token), terminalId, expiresAt },
  });
  return { token, issuedAt, expiresAt };
}
