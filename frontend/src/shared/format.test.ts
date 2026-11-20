import { describe, expect, it } from "vitest";
import { formatDateOnly, formatDateTime, locationLabel, maskDocument, normalizeUid, timeAgo } from "./format";

describe("normalizeUid", () => {
  it("remove separadores e deixa em hexadecimal maiúsculo", () => {
    expect(normalizeUid("04:a3-2f 1b")).toBe("04A32F1B");
  });
});

describe("maskDocument", () => {
  it("oculta tudo menos os 3 últimos caracteres, mantendo a pontuação", () => {
    expect(maskDocument("111.222.333-44")).toBe("•••.•••.••3-44");
  });
  it("não oculta documentos muito curtos", () => {
    expect(maskDocument("AB1")).toBe("AB1");
  });
});

describe("datas", () => {
  it("formatDateOnly não desloca o dia pelo fuso", () => {
    expect(formatDateOnly("2026-10-17")).toBe("17/10/2026");
  });
  it("formatDateTime exibe em America/Sao_Paulo (UTC-3)", () => {
    expect(formatDateTime("2026-10-17T15:00:00.000Z")).toContain("12:00:00");
  });
  it("formatDateTime mostra traço quando não há data", () => {
    expect(formatDateTime(null)).toBe("—");
  });
});

describe("locationLabel", () => {
  it("junta apenas as partes preenchidas", () => {
    expect(locationLabel({ id: "1", building: "Bloco A", entrance: null, door: "Sala 2", turnstile: null, description: null })).toBe("Bloco A / Sala 2");
  });
});

describe("timeAgo", () => {
  const now = new Date("2026-11-09T12:00:00.000Z").getTime();
  it("usa segundos e minutos para eventos recentes", () => {
    expect(timeAgo("2026-11-09T11:59:48.000Z", now)).toBe("há 12 s");
    expect(timeAgo("2026-11-09T11:57:00.000Z", now)).toBe("há 3 min");
  });
  it("mostra a data completa para eventos antigos e 'Nunca' sem data", () => {
    expect(timeAgo("2026-11-08T12:00:00.000Z", now)).toContain("/11/2026");
    expect(timeAgo(null, now)).toBe("Nunca");
  });
});
