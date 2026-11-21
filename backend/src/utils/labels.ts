// backend/src/utils/labels.ts
// Rótulos em português usados nas exportações (iguais aos exibidos no frontend).
export const METHOD_LABEL: Record<string, string> = { QR: "QR Code", NFC: "Tag NFC", FACE: "Facial" };
export const RESULT_LABEL: Record<string, string> = { GRANTED: "Liberado", DENIED: "Negado" };
export const REASON_LABEL: Record<string, string> = {
  INVALID_CREDENTIAL: "Credencial inválida",
  EXPIRED_CREDENTIAL: "Credencial vencida",
  REPLAYED_CREDENTIAL: "Credencial já utilizada",
  USER_INACTIVE: "Usuário inativo",
  NO_AUTHORIZATION: "Sem autorização para o local",
  AUTHORIZATION_CANCELED: "Autorização cancelada",
  OUTSIDE_PERIOD: "Fora do período",
  OUTSIDE_SCHEDULE: "Fora do horário",
  USES_EXHAUSTED: "Usos esgotados",
  TOO_FAR: "Longe do terminal",
  FACE_LOW_CONFIDENCE: "Rosto com baixa confiança",
  TERMINAL_OFFLINE: "Terminal offline",
};
