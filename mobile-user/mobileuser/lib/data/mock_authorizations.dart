import 'authorization.dart';

/// Dados falsos. Substituir por GET /me/authorizations depois.
const mockAuthorizations = <Authorization>[
  Authorization(
    id: '1',
    place: 'Portaria Principal',
    period: '01/10/2026 a 31/12/2026',
    timeWindow: '06:00 às 22:00',
    remainingUses: null,
    status: AuthorizationStatus.active,
  ),
  Authorization(
    id: '2',
    place: 'Salão de Festas',
    period: '18/10/2026',
    timeWindow: '14:00 às 23:00',
    remainingUses: 1,
    status: AuthorizationStatus.active,
  ),
  Authorization(
    id: '3',
    place: 'Garagem Bloco B',
    period: '01/06/2026 a 30/09/2026',
    timeWindow: '24 horas',
    remainingUses: 0,
    status: AuthorizationStatus.expired,
  ),
  Authorization(
    id: '4',
    place: 'Academia',
    period: '05/08/2026 a 05/11/2026',
    timeWindow: '06:00 às 21:00',
    remainingUses: 12,
    status: AuthorizationStatus.cancelled,
  ),
];
