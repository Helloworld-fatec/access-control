# Firmware ESP32

O firmware integrado está em `hardware/firmware/controle_acesso/controle_acesso.ino`.
Detalhes da montagem, pinagem, dependências e limitações estão em
[`hardware/README.md`](hardware/README.md) e
[`hardware/firmware/LEIA-ME.md`](hardware/firmware/LEIA-ME.md).

## CI

O workflow `.github/workflows/device-esp32-ci.yml` compila o firmware para a
placa **ESP32 Dev Module** em PRs para `stage` e `main`. Ele instala o Arduino
CLI, o core ESP32 e as bibliotecas utilizadas pelo sketch. O workflow não grava
firmware em uma placa nem substitui os testes físicos; a branch `develop` está
comentada até entrar no fluxo.
