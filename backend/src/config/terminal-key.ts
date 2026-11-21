import { createHash, randomBytes } from "node:crypto";

export const terminalKeyPattern = /^[0-9a-fA-F]{6}$/;

export function hashTerminalKey(key: string): string {
  return createHash("sha256").update(key.toLowerCase()).digest("hex");
}

export function generateTerminalKey(): string {
  return randomBytes(3).toString("hex");
}
