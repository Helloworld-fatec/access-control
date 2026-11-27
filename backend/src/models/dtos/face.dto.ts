import { z } from "zod";

export const upsertFaceSchema = z.strictObject({
  consent: z.literal("true", { error: "É necessário o consentimento do usuário (LGPD)" }),
});
