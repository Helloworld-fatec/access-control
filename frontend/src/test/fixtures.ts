import type { Authorization, Location, Paginated, Terminal, User } from "../shared/types";

export const page = <T,>(data: T[]): Paginated<T> => ({ data, page: 1, pageSize: 20, total: data.length, totalPages: 1 });

export const admin: User = { id: "u1", name: "Administrador", document: null, email: "admin@teste.com", phone: null, role: "ADMIN", active: true, createdAt: "2026-10-01T12:00:00.000Z" };
export const marina: User = { id: "u2", name: "Marina Duarte", document: "111.222.333-44", email: "marina@teste.com", phone: null, role: "RESIDENT", active: true, createdAt: "2026-10-02T12:00:00.000Z" };
export const bloco: Location = { id: "l1", building: "Bloco A", entrance: "Portaria", door: null, turnstile: null, description: null };
export const terminal: Terminal = { id: "t1", name: "Portaria A", locationId: "l1", latitude: -23.55, longitude: -46.63, online: true, lastPresenceAt: null, lastSeenAt: null };
export const activeAuth: Authorization = {
  id: "a1", userId: "u2", locationId: "l1", startDate: "2026-10-01", endDate: "2026-12-31", startTime: "08:00", endTime: "18:00",
  maxUses: 5, usedCount: 2, remainingUses: 3, status: "ACTIVE", location: bloco, user: { id: "u2", name: "Marina Duarte" },
};
