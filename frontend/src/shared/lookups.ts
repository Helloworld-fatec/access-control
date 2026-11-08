import { useQuery } from "@tanstack/react-query";
import { api } from "./api";
import type { Location, Paginated, Terminal, User } from "./types";

// Listas para os selects dos filtros e formulários. O backend limita pageSize a 100.
// TODO: trocar por campo com busca quando houver mais de 100 registros.
export const useUserOptions = () =>
  useQuery({ queryKey: ["options", "users"], queryFn: () => api<Paginated<User>>("/users", { query: { pageSize: 100 } }) });

export const useLocationOptions = () =>
  useQuery({ queryKey: ["options", "locations"], queryFn: () => api<Paginated<Location>>("/locations", { query: { pageSize: 100 } }) });

export const useTerminalOptions = () =>
  useQuery({ queryKey: ["options", "terminals"], queryFn: () => api<Paginated<Terminal>>("/terminals", { query: { pageSize: 100 } }) });
