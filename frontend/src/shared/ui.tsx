import { useEffect, useRef, type ReactNode } from "react";
import { ApiError } from "./api";

export function PageHeader({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <header className="page-header">
      <h1>{title}</h1>
      <div className="row">{children}</div>
    </header>
  );
}

export function Badge({ tone, children }: { tone: "ok" | "bad" | "warn" | "muted"; children: ReactNode }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

/** Estados de carregamento, vazio e erro em toda tela (US-18). */
export function QueryState({
  isLoading,
  error,
  empty,
  emptyText,
  onRetry,
  children,
}: {
  isLoading: boolean;
  error: unknown;
  empty: boolean;
  emptyText: string;
  onRetry?: () => void;
  children: ReactNode;
}) {
  if (isLoading) return <p className="state" role="status">Carregando…</p>;
  if (error)
    return (
      <div className="state state-error" role="alert">
        <p>{errorMessage(error)}</p>
        {onRetry && <button className="btn" onClick={onRetry}>Tentar de novo</button>}
      </div>
    );
  if (empty) return <p className="state">{emptyText}</p>;
  return <>{children}</>;
}

export const errorMessage = (e: unknown) => (e instanceof ApiError || e instanceof Error ? e.message : "Algo deu errado.");

export function Pagination({
  page,
  totalPages,
  total,
  onPage,
}: {
  page: number;
  totalPages: number;
  total: number;
  onPage: (p: number) => void;
}) {
  return (
    <nav className="pagination" aria-label="Paginação">
      <span>{total} {total === 1 ? "registro" : "registros"}</span>
      <div className="row">
        <button className="btn" disabled={page <= 1} onClick={() => onPage(page - 1)}>Anterior</button>
        <span>Página {page} de {totalPages}</span>
        <button className="btn" disabled={page >= totalPages} onClick={() => onPage(page + 1)}>Próxima</button>
      </div>
    </nav>
  );
}

export function Modal({
  title,
  onClose,
  children,
  wide,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
  wide?: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const d = ref.current;
    if (d && !d.open) d.showModal();
  }, []);
  return (
    <dialog ref={ref} className={wide ? "modal modal-wide" : "modal"} onClose={onClose} aria-labelledby="modal-title">
      <h2 id="modal-title">{title}</h2>
      {children}
    </dialog>
  );
}

/** Confirmação antes de ações destrutivas (US-18). */
export function ConfirmDialog({
  title,
  message,
  confirmLabel,
  danger,
  busy,
  error,
  onConfirm,
  onCancel,
}: {
  title: string;
  message: string;
  confirmLabel: string;
  danger?: boolean;
  busy?: boolean;
  error?: unknown;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Modal title={title} onClose={onCancel}>
      <p>{message}</p>
      {error ? <p className="form-error" role="alert">{errorMessage(error)}</p> : null}
      <div className="actions">
        <button className="btn" onClick={onCancel} disabled={busy}>Voltar</button>
        <button className={danger ? "btn btn-danger" : "btn btn-primary"} onClick={onConfirm} disabled={busy}>
          {busy ? "Aguarde…" : confirmLabel}
        </button>
      </div>
    </Modal>
  );
}

export function Field({
  label,
  error,
  hint,
  children,
}: {
  label: string;
  error?: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      {children}
      {hint && !error && <span className="field-hint">{hint}</span>}
      {error && <span className="field-error" role="alert">{error}</span>}
    </label>
  );
}
