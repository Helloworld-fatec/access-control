# Ajuste sugerido no backend: tag NFC e rosto na listagem

A US-06 pede que cada item da lista indique se há **tag NFC** e **rosto** vinculados.
Hoje `GET /users` devolve só os dados do usuário; `hasFace` e as tags só vêm em
`GET /users/{id}`. O app **já está pronto**: mostra "Com/Sem tag NFC" e "Com/Sem rosto"
quando `nfcTagCount` e `hasFace` chegam na listagem, e esconde os indicadores quando não chegam.

Buscar o detalhe de cada usuário para preencher a lista seria uma chamada por item (lento). O
ajuste abaixo resolve com a mesma consulta, sem novas rotas.

## `backend/src/models/user.model.ts`

```ts
/** Item da listagem: o usuário + indicadores de tag e rosto. */
export interface UserListItem extends UserResponse {
  hasFace: boolean;
  nfcTagCount: number;
}

export function toUserListItem(
  u: UserRow & { _count: { nfcTags: number }; faceTemplate: unknown | null },
): UserListItem {
  return {
    ...toUserResponse(u),
    hasFace: u.faceTemplate != null, // nunca expõe o embedding
    nfcTagCount: u._count.nfcTags,
  };
}
```

(Exporte `toUserListItem` em `models/index.ts`, como as demais funções.)

## `backend/src/controllers/users.controller.ts` (`listUsers`)

```ts
const [rows, total] = await prisma.$transaction([
  prisma.user.findMany({
    where,
    orderBy: { name: "asc" },
    skip: (q.page - 1) * q.pageSize,
    take: q.pageSize,
    include: {
      _count: { select: { nfcTags: true } },
      faceTemplate: { select: { id: true } },
    },
  }),
  prisma.user.count({ where }),
]);

res.json(paginate(rows.map(toUserListItem), total, q.page, q.pageSize));
```

O formato continua `{ data, page, pageSize, total, totalPages }`; só ganha dois campos por item.
O frontend web não é afetado (campos extras são ignorados).

O servidor de desenvolvimento do app (`tool/dev_auth_server.dart`) já responde assim.
