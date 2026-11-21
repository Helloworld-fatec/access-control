# Mobile Readings

Terminal Flutter para acesso por **QR Code** ou **reconhecimento facial**. Configure o endereço do servidor e a chave hexadecimal de seis caracteres. Depois, toque em **Iniciar acesso** e escolha o modo.

## Contratos do terminal

| Rota | Função |
| --- | --- |
| `GET /api/terminals/me` | Valida a chave do terminal e resolve seu UUID. |
| `POST /api/terminals/me/qr` | Emite o JSON exibido pelo terminal. Renova a cada 10 segundos e expira em 20 segundos. |
| `POST /api/access/face/capture` | Recebe um lote JPEG e devolve a decisão de acesso. |

As três rotas usam `x-terminal-key`. O app do usuário consome o QR com `POST /api/access/qr/consume`.

No modo facial, **Iniciar reconhecimento** captura até três fotos com a câmera frontal no preset baixo, com intervalo de 250 ms. O app envia somente JPEGs de até 100 KB em um único POST com UUID por tentativa. Exibe concessão quando o backend declara `GRANTED` com `allowed: true`. Em recusa ou indisponibilidade, oferece uma nova captura ou QR Code. O contrato do serviço e a migração necessária estão no [README de reconhecimento facial](../face-recognition/README.md).

## Como Executar

```bash
cd mobile-readings
flutter pub get
flutter run
```

### Executar Análise Estática e Testes Automatizados (`US-21`)

```bash
flutter analyze
flutter test
```

Para reproduzir o fluxo completo e conferir os resultados esperados, consulte o [roteiro da demonstração](../docs/demonstracao-mobile-readings.md).
