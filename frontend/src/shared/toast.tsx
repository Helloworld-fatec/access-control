import { createContext, useCallback, useContext, useState, type ReactNode } from "react";

type Show = (text: string) => void;
const Ctx = createContext<Show>(() => {});

/** Aviso de sucesso que some sozinho; é lido por leitores de tela (aria-live). */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<{ id: number; text: string }[]>([]);
  const show = useCallback<Show>((text) => {
    const id = Date.now() + Math.random();
    setItems((p) => [...p, { id, text }]);
    setTimeout(() => setItems((p) => p.filter((i) => i.id !== id)), 5000);
  }, []);
  return (
    <Ctx.Provider value={show}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {items.map((i) => (
          <div key={i.id} className="toast">{i.text}</div>
        ))}
      </div>
    </Ctx.Provider>
  );
}

export const useToast = () => useContext(Ctx);
