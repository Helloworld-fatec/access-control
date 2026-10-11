// backend/src/models/user.model.ts
import type { UserRole } from "../types/index";

/** Linha do banco (estrutural, compatível com o que o Prisma devolve). */
export interface UserRow {
  id: string;
  name: string;
  document: string | null;
  email: string;
  phone: string | null;
  passwordHash: string;
  role: string;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/** O que a API devolve: nunca inclui passwordHash. */
export interface UserResponse {
  id: string;
  name: string;
  document: string | null;
  email: string;
  phone: string | null;
  role: UserRole;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/** Resumo do cadastro biométrico/credenciais, exibido no detalhe do usuário. */
export interface UserDetailResponse extends UserResponse {
  hasFace: boolean;
  hasPhoto: boolean;
  nfcTags: NfcTagResponse[];
}

export interface NfcTagRow {
  id: string;
  uid: string;
  userId: string;
  active: boolean;
  createdAt: Date;
}

export type NfcTagResponse = NfcTagRow;

export function toUserResponse(u: UserRow): UserResponse {
  return {
    id: u.id,
    name: u.name,
    document: u.document,
    email: u.email,
    phone: u.phone,
    role: u.role as UserRole,
    active: u.active,
    createdAt: u.createdAt,
    updatedAt: u.updatedAt,
  };
}

export function toNfcTagResponse(t: NfcTagRow): NfcTagResponse {
  return {
    id: t.id,
    uid: t.uid,
    userId: t.userId,
    active: t.active,
    createdAt: t.createdAt,
  };
}

export function toUserDetailResponse(
  u: UserRow & {
    nfcTags: NfcTagRow[];
    faceTemplate: unknown | null;
    photo: unknown | null;
  },
): UserDetailResponse {
  return {
    ...toUserResponse(u),
    hasFace: u.faceTemplate != null, // nunca expõe o embedding
    hasPhoto: u.photo != null,
    nfcTags: u.nfcTags.map(toNfcTagResponse),
  };
}
