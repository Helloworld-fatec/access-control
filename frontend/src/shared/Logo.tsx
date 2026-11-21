/** Ícone original do sistema: um cartão de acesso dentro de um círculo. Decorativo. */
export default function Logo({ size = 40, color = "currentColor" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" fill="none" aria-hidden="true" focusable="false">
      <circle cx="20" cy="20" r="17" stroke={color} strokeWidth="4" />
      <circle cx="15" cy="20" r="4.2" stroke={color} strokeWidth="3.4" />
      <path d="M19.2 20h10M26 20v4.5M29.2 20v3" stroke={color} strokeWidth="3.4" strokeLinecap="round" />
    </svg>
  );
}
