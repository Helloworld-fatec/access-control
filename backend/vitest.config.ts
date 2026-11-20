import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    env: {
      DATABASE_URL: 'postgresql://usuario:senha@localhost:5432/meu_banco?schema=public',
      PORT: '3000',
      JWT_SECRET: 'minha_chave_secreta_super_segura_de_32_caracteres_minimo',
      NODE_ENV: 'test',
    },
  },
});