CREATE TABLE "visit_pokemon_draws" (
    "visitId" UUID NOT NULL,
    "pokemonId" VARCHAR(3) NOT NULL,
    "drawnAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "visit_pokemon_draws_pkey" PRIMARY KEY ("visitId"),
    CONSTRAINT "visit_pokemon_draws_pokemonId_check" CHECK ("pokemonId" ~ '^[0-9]{3}$'),
    CONSTRAINT "visit_pokemon_draws_visitId_fkey"
        FOREIGN KEY ("visitId") REFERENCES "visits"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "visit_pokemon_draws_visitId_pokemonId_key"
    ON "visit_pokemon_draws"("visitId", "pokemonId");

CREATE TABLE "user_pokemon" (
    "visitId" UUID NOT NULL,
    "userId" TEXT NOT NULL,
    "pokemonId" VARCHAR(3) NOT NULL,
    "claimedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "user_pokemon_pkey" PRIMARY KEY ("visitId"),
    CONSTRAINT "user_pokemon_visitId_pokemonId_fkey"
        FOREIGN KEY ("visitId", "pokemonId")
        REFERENCES "visit_pokemon_draws"("visitId", "pokemonId") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "user_pokemon_userId_fkey"
        FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "user_pokemon_visitId_pokemonId_key" ON "user_pokemon"("visitId", "pokemonId");
CREATE INDEX "user_pokemon_userId_claimedAt_idx" ON "user_pokemon"("userId", "claimedAt");
