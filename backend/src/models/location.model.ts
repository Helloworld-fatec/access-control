// backend/src/models/location.model.ts

export interface LocationRow {
  id: string;
  building: string;
  entrance: string | null;
  door: string | null;
  turnstile: string | null;
  description: string | null;
}

export type LocationResponse = LocationRow;

export function toLocationResponse(l: LocationRow): LocationResponse {
  return {
    id: l.id,
    building: l.building,
    entrance: l.entrance,
    door: l.door,
    turnstile: l.turnstile,
    description: l.description,
  };
}
