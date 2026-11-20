import type { AccessMethod } from "../types/index.js";

export interface DoorUnlockRequest {
  terminalId: string;
  userId: string;
  accessLogId: string;
  method: AccessMethod;
}

/**
 * Ponto único para solicitar a abertura da porta. A integração MQTT com o
 * Arduino ainda não existe; por enquanto, esta função simula a publicação.
 * O fluxo facial deve chamar o mesmo helper após persistir uma concessão.
 */
export async function requestDoorUnlock(request: DoorUnlockRequest): Promise<void> {
  console.log(
    "[MQTT SIMULADO] Usuário liberado; solicitar abertura da porta:",
    JSON.stringify(request),
  );
}
