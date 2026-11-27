import { describe, expect, it } from "vitest";
import { CSV_BOM, csvCell, csvLine, formatSaoPaulo } from "../utils/csv.js";

describe("csvCell", () => {
  it("deixa texto simples como está e vazio para null/undefined", () => {
    expect(csvCell("Maria")).toBe("Maria");
    expect(csvCell(null)).toBe("");
    expect(csvCell(undefined)).toBe("");
    expect(csvCell(0)).toBe("0");
    expect(csvCell(false)).toBe("false");
  });

  it("coloca entre aspas quando há separador, aspas ou quebra de linha", () => {
    expect(csvCell("Silva; Ana")).toBe('"Silva; Ana"');
    expect(csvCell('Disse "oi"')).toBe('"Disse ""oi"""');
    expect(csvCell("a\nb")).toBe('"a\nb"');
  });

  it("não aspeia vírgula, já que o separador é ponto e vírgula", () => {
    expect(csvCell("Silva, Ana")).toBe("Silva, Ana");
  });

  it.each(["=SOMA(A1)", "+1", "-2", "@cmd", "\tx"])("neutraliza fórmula em %j", (v) => {
    expect(csvCell(v).startsWith("'")).toBe(true);
  });

  it("não altera traço ou sinal no meio do texto", () => {
    expect(csvCell("Portaria A-1")).toBe("Portaria A-1");
  });
});

describe("csvLine", () => {
  it("junta com ponto e vírgula e termina em CRLF", () => {
    expect(csvLine(["a", "b;c", null])).toBe('a;"b;c";\r\n');
  });
});

describe("formatSaoPaulo", () => {
  it("converte UTC para -03:00", () => {
    expect(formatSaoPaulo(new Date("2026-11-19T21:13:56.000Z"))).toBe("19/11/2026 18:13:56");
  });
  it("vira o dia corretamente depois da meia-noite UTC", () => {
    expect(formatSaoPaulo(new Date("2026-01-01T02:30:00.000Z"))).toBe("31/12/2025 23:30:00");
  });
});

it("BOM é o caractere U+FEFF", () => {
  expect(CSV_BOM.charCodeAt(0)).toBe(0xfeff);
});
