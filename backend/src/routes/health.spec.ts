import { describe, it, expect } from 'vitest';
import request from 'supertest';
import { app } from '../index'; // Ou '../server' se o app estiver exportado no server.ts

describe('GET /api/health (US-01)', () => {
  it('deve retornar status 200 e indicar que a API está saudável', async () => {
    const response = await request(app).get('/api/health');

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('status', 'ok');
  });
});