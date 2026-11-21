/** Entrega um arquivo ao usuário pelo navegador (sem abrir outra página). */
export function saveBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.rel = "noopener";
  document.body.appendChild(a);
  a.click();
  a.remove();
  // Dá tempo ao navegador de iniciar o download antes de liberar a memória.
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}
