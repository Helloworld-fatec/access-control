import { act, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import type { PokemonDraw, Visit } from "../../shared/types";
import PokemonCheckoutDialog from "./PokemonCheckoutDialog";

const time = "2026-11-24T10:00:00Z";
const visit: Visit = {
  id: "visit", status: "INSIDE", user: { id: "person", name: "Marina" },
  location: { id: "loc", building: "Laboratório", door: null, entrance: null, turnstile: null },
  entryTerminal: { id: "door", name: "Entrada" },
  entryLog: { id: "entry", method: "QR", commandAcked: true },
  enteredAt: time, exitedAt: null, checkoutType: null, checkedOutBy: null, pokemon: null, doorCommand: null,
};
const draw: PokemonDraw = {
  visitId: visit.id, drawnAt: time,
  pokemon: {
    id: "001", numero: 1, nome: "Bulbasaur", altura_m: 0.7, peso_kg: 6.9,
    stats: { hp: 45, attack: 49, defense: 49, "special-attack": 65, "special-defense": 65, speed: 45 },
    imagem_url: "/api/pokemon/001/image",
  },
};
const claim = vi.fn();
const close = vi.fn();

function show() {
  return render(
    <PokemonCheckoutDialog visit={visit} draw={draw} drawing={false} drawError={null}
      claiming={false} claimError={null} onRetry={() => {}} onClaim={claim} onClose={close} />,
  );
}

function advance(milliseconds: number) {
  act(() => vi.advanceTimersByTime(milliseconds));
}

beforeEach(() => {
  vi.useFakeTimers();
  claim.mockClear();
  close.mockClear();
  vi.spyOn(HTMLMediaElement.prototype, "play").mockResolvedValue(undefined);
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

it("conta cinco segundos, aguarda o MP4 e revela após a luz", () => {
  const { container } = show();
  const video = container.querySelector("video")!;
  expect(video).toHaveAttribute("src", "/pokebola-clipe.mp4");
  expect(video).toHaveAttribute("hidden");
  for (const number of ["5", "4", "3", "2", "1"]) {
    expect(screen.getByText(number)).toBeInTheDocument();
    expect(screen.queryByRole("img", { name: "Bulbasaur" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Pegar Pokémon" })).not.toBeInTheDocument();
    advance(1000);
  }
  expect(video).not.toHaveAttribute("hidden");
  expect(video.play).toHaveBeenCalledTimes(1);
  expect(claim).not.toHaveBeenCalled();
  fireEvent.ended(video);
  const light = container.querySelector(".pokemon-light")!;
  expect(light).toBeInTheDocument();
  expect(screen.queryByRole("img", { name: "Bulbasaur" })).not.toBeInTheDocument();
  advance(750);
  expect(screen.getByRole("img", { name: "Bulbasaur" })).toBeInTheDocument();
  expect(claim).not.toHaveBeenCalled();
  fireEvent.click(screen.getByRole("button", { name: "Pegar Pokémon" }));
  expect(claim).toHaveBeenCalledTimes(1);
});

it("mantém o resultado quando o vídeo falha durante o carregamento", () => {
  const { container } = show();
  fireEvent.error(container.querySelector("video")!);
  advance(5000);
  expect(container.querySelector(".pokemon-light")).toBeInTheDocument();
  advance(750);
  expect(screen.getByRole("img", { name: "Bulbasaur" })).toBeInTheDocument();
  expect(claim).not.toHaveBeenCalled();
});

it("mantém a contagem e revela sem vídeo ou luz com movimento reduzido", () => {
  vi.stubGlobal("matchMedia", () => ({ matches: true }));
  const { container } = show();
  expect(container.querySelector("video")).not.toBeInTheDocument();
  advance(5000);
  expect(container.querySelector(".pokemon-light")).not.toBeInTheDocument();
  expect(screen.getByRole("img", { name: "Bulbasaur" })).toBeInTheDocument();
});
