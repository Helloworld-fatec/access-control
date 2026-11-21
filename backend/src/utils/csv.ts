// backend/src/utils/csv.ts
// CSV no padrão que o Excel em português abre direto: separador ";", quebra de linha CRLF e BOM UTF-8.
export const CSV_SEPARATOR = ";";
export const CSV_BOM = "﻿";

/**
 * Escapa uma célula. Além das aspas, neutraliza "injeção de fórmula": nomes digitados por usuários
 * que começam com = + - @ (ou tab/CR) seriam executados como fórmula ao abrir no Excel.
 */
export function csvCell(value: string | number | boolean | null | undefined): string {
  if (value === null || value === undefined) return "";
  let s = String(value);
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[";\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

export const csvLine = (cells: Array<string | number | boolean | null | undefined>): string =>
  cells.map(csvCell).join(CSV_SEPARATOR) + "\r\n";

const pad = (n: number) => String(n).padStart(2, "0");

/** dd/MM/yyyy HH:mm:ss no horário de São Paulo (sem horário de verão: fixo em -03:00). */
export function formatSaoPaulo(date: Date): string {
  const d = new Date(date.getTime() - 3 * 60 * 60 * 1000);
  return `${pad(d.getUTCDate())}/${pad(d.getUTCMonth() + 1)}/${d.getUTCFullYear()} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`;
}
