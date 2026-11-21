import { afterEach, describe, expect, it, vi } from "vitest";
import { saveBlob } from "./download";

describe("saveBlob", () => {
  afterEach(() => vi.restoreAllMocks());

  it("cria um link temporário com o nome do arquivo, clica e remove", () => {
    URL.createObjectURL = vi.fn(() => "blob:fake");
    URL.revokeObjectURL = vi.fn();
    const click = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(function (this: HTMLAnchorElement) {
      expect(this.download).toBe("historico.csv");
      expect(this.href).toBe("blob:fake");
    });
    vi.useFakeTimers();
    saveBlob(new Blob(["a;b"]), "historico.csv");
    expect(click).toHaveBeenCalledOnce();
    expect(document.querySelector("a[download]")).toBeNull();
    expect(URL.revokeObjectURL).not.toHaveBeenCalled();
    vi.advanceTimersByTime(10_000);
    expect(URL.revokeObjectURL).toHaveBeenCalledWith("blob:fake");
    vi.useRealTimers();
  });
});
