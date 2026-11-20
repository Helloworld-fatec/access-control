import type { Request, RequestHandler } from "express";

interface RateLimitOptions {
  windowMs: number;
  max: number;
  key: (req: Request) => string;
}

interface Bucket {
  count: number;
  resetAt: number;
}

/** Limite simples em memória, adequado a uma instância do backend. */
export function rateLimit({ windowMs, max, key }: RateLimitOptions): RequestHandler {
  const buckets = new Map<string, Bucket>();

  return (req, res, next) => {
    const now = Date.now();
    if (buckets.size > 1000) {
      for (const [bucketKey, bucket] of buckets) {
        if (bucket.resetAt <= now) buckets.delete(bucketKey);
      }
    }

    const bucketKey = key(req);
    const current = buckets.get(bucketKey);
    const bucket = !current || current.resetAt <= now
      ? { count: 0, resetAt: now + windowMs }
      : current;

    if (bucket.count >= max) {
      res.setHeader("Retry-After", String(Math.max(1, Math.ceil((bucket.resetAt - now) / 1000))));
      res.status(429).json({
        error: { code: "TOO_MANY_REQUESTS", message: "Muitas tentativas; tente novamente em instantes" },
      });
      return;
    }

    bucket.count += 1;
    buckets.set(bucketKey, bucket);
    next();
  };
}
