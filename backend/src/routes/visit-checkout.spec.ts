import jwt from "jsonwebtoken";
import request from "supertest";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { env } from "../config/env.js";
import { app } from "../index.js";

const { db, targetId, configuredDoorTerminalId } = vi.hoisted(() => ({
  targetId: "df96f695-a94c-4a4d-9ac5-f90beca3cd71",
  configuredDoorTerminalId: vi.fn(),
  db: {
    $queryRaw: vi.fn(),
    $transaction: vi.fn(),
    user: { findUnique: vi.fn() },
    terminal: { findFirst: vi.fn() },
    visit: { update: vi.fn(), findUnique: vi.fn(), findUniqueOrThrow: vi.fn() },
    visitPokemonDraw: { findUnique: vi.fn(), create: vi.fn() },
    userPokemon: { create: vi.fn() },
    mqttDoorCommand: { create: vi.fn() },
  },
}));
vi.mock("../config/prisma.js", () => ({ prisma: db }));
vi.mock("../services/door-unlock.service.js", async (original) => ({
  ...await original<typeof import("../services/door-unlock.service.js")>(), configuredDoorTerminalId,
}));

const visitId = "14825695-6cdb-4e40-a33e-94045475eabb";
const adminId = "0def53e9-0c89-4f73-9801-b1b23803476d";
const locationId = "0b71ee1e-7105-42d1-ab72-291ce84938eb";
const path = `/api/visits/${visitId}`;
const current = new Date("2026-11-23T12:01:00Z");
const open = { id: visitId, userId: "user", locationId, exitedAt: null, checkoutType: null };
const grant = { visitId, pokemonId: "001", drawnAt: current };
const api = request(app);
const post = (suffix: string) => api.post(path + suffix).set("Authorization", bearer());

function bearer() {
  return `Bearer ${jwt.sign({ role: "ADMIN" }, env.JWT_SECRET, { subject: adminId })}`;
}

beforeEach(() => {
  vi.resetAllMocks();
  vi.setSystemTime(current);
  db.user.findUnique.mockResolvedValue({ active: true, role: "ADMIN" });
  db.$transaction.mockImplementation((run) => run(db));
  db.$queryRaw.mockResolvedValue([open]);
  db.terminal.findFirst.mockResolvedValue({ id: targetId });
  configuredDoorTerminalId.mockReturnValue(targetId);
});
afterEach(() => vi.useRealTimers());

it("registra e repete o checkout simples sem Pokémon nem comando", async () => {
  const closed = { ...open, exitedAt: current, checkoutType: "SIMPLE" };
  db.visit.update.mockResolvedValue(closed);
  db.visit.findUniqueOrThrow.mockResolvedValue(closed);
  const first = await post("/checkout");
  expect(first.status).toBe(200);
  expect(first.body).toMatchObject({ status: "EXITED", checkoutType: "SIMPLE", pokemon: null, doorCommand: null });
  db.$queryRaw.mockResolvedValue([closed]);
  expect((await post("/checkout")).body).toEqual(first.body);
  expect((await post("/pokemon/claim")).status).toBe(409);
  expect(db.visit.update).toHaveBeenCalledTimes(1);
  expect(db.userPokemon.create).not.toHaveBeenCalled();
  expect(db.mqttDoorCommand.create).not.toHaveBeenCalled();
});

it("revelar um Pokémon mantém a visita aberta e devolve o sorteio existente", async () => {
  db.visitPokemonDraw.findUnique.mockResolvedValue(grant);
  const response = await post("/pokemon/draw");
  expect(response.status).toBe(200);
  expect(response.body).toMatchObject({ visitId, pokemon: { id: "001", nome: "Bulbasaur" } });
  expect(db.visit.update).not.toHaveBeenCalled();
  expect(db.userPokemon.create).not.toHaveBeenCalled();
  expect(db.mqttDoorCommand.create).not.toHaveBeenCalled();
});

it("confirma o Pokémon e cria apenas um comando para a porta do mesmo local", async () => {
  db.visitPokemonDraw.findUnique.mockResolvedValue(grant);
  const command = {
    id: "command", terminalId: targetId, issuedAt: current,
    expiresAt: new Date(current.getTime() + 5000), ackAt: null, ackResult: null,
  };
  const closed = {
    ...open, exitedAt: current, checkoutType: "POKEMON",
    pokemonDraw: { collection: { pokemonId: "001", claimedAt: current } },
    checkoutDoorCommand: command,
  };
  db.visit.update.mockResolvedValue(closed);
  db.visit.findUniqueOrThrow.mockResolvedValue(closed);
  const first = await post("/pokemon/claim");
  expect(first.status).toBe(200);
  expect(first.body).toMatchObject({ status: "EXITED", pokemon: { pokemonId: "001" }, doorCommand: { status: "PENDING" } });
  expect(db.terminal.findFirst).toHaveBeenCalledWith({
    where: { id: targetId, locationId }, select: { id: true },
  });
  expect(db.userPokemon.create).toHaveBeenCalledExactlyOnceWith({
    data: { visitId, userId: "user", pokemonId: "001", claimedAt: current },
  });
  expect(db.mqttDoorCommand.create).toHaveBeenCalledExactlyOnceWith({
    data: { checkoutVisitId: visitId, terminalId: targetId, issuedAt: current, expiresAt: command.expiresAt },
  });
  expect(db.visit.update).toHaveBeenCalledWith(expect.objectContaining({
    data: { exitedAt: current, checkoutType: "POKEMON", checkedOutById: adminId },
  }));
  db.$queryRaw.mockResolvedValue([closed]);
  expect((await post("/pokemon/claim")).body).toEqual(first.body);
  expect((await post("/checkout")).status).toBe(409);
  expect(db.userPokemon.create).toHaveBeenCalledTimes(1);
  expect(db.mqttDoorCommand.create).toHaveBeenCalledTimes(1);

  db.visit.findUnique.mockResolvedValue(closed);
  const get = () => api.get(path).set("Authorization", bearer());
  vi.setSystemTime(new Date(current.getTime() + 15_000));
  expect((await get()).body.doorCommand.status).toBe("EXPIRED");
  db.visit.findUnique.mockResolvedValue({
    ...closed, checkoutDoorCommand: { ...command, ackResult: "UNLOCKED", ackAt: new Date() },
  });
  expect((await get()).body.doorCommand.status).toBe("CONFIRMED");
});

it("confirmação sem sorteio ou porta elegível mantém a visita aberta", async () => {
  expect((await post("/pokemon/claim")).body.error.code).toBe("POKEMON_DRAW_REQUIRED");
  db.visitPokemonDraw.findUnique.mockResolvedValue(grant);
  db.terminal.findFirst.mockResolvedValue(null);
  expect((await post("/pokemon/claim")).body.error.code).toBe("CHECKOUT_DOOR_UNAVAILABLE");
  expect(db.visit.update).not.toHaveBeenCalled();
  expect(db.userPokemon.create).not.toHaveBeenCalled();
  expect(db.mqttDoorCommand.create).not.toHaveBeenCalled();
});

it("nega os checkouts a quem não é administrador", async () => {
  db.user.findUnique.mockResolvedValue({ active: true, role: "RESIDENT" });
  for (const route of ["/checkout", "/pokemon/draw", "/pokemon/claim"]) {
    expect((await post(route)).status).toBe(403);
  }
  expect(db.$transaction).not.toHaveBeenCalled();
});
