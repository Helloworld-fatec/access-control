import type { FieldValues, Path, UseFormSetError } from "react-hook-form";
import { ApiError } from "./api";

/** Coloca os erros de validação do backend junto aos campos (US-05). Devolve a mensagem geral, se houver. */
export function applyApiErrors<T extends FieldValues>(e: unknown, setError: UseFormSetError<T>, fields: string[]): string | null {
  if (!(e instanceof ApiError)) return "Algo deu errado. Tente novamente.";
  let leftover = false;
  for (const d of e.details ?? []) {
    if (fields.includes(d.path)) setError(d.path as Path<T>, { message: d.message });
    else leftover = true;
  }
  return !e.details?.length || leftover ? e.message : null;
}
