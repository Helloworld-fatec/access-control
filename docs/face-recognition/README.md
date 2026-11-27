# Face Recognition

Serviço interno em Python/FastAPI para extrair descritores HOG no cadastro e comparar capturas do terminal com os templates fornecidos pelo backend.

## Contrato HTTP

- `GET /health` responde `200` com `{"status":"ok"}`. Indica que o processo HTTP responde.
- `POST /extract` recebe `multipart/form-data` com um único arquivo `photo` do tipo `image/jpeg`. O limite da foto é 102.400 bytes e 4 milhões de pixels. O limite do corpo multipart inteiro é 118.784 bytes. A foto é validada em memória.
- Em caso de sucesso, a rota responde `200` com `embedding` (1.764 números finitos na ordem do OpenCV) e `modelVersion` (`hog-v1`).

Os erros têm o formato `{"detail":{"code":"PHOTO_REQUIRED"}}`.

| HTTP | Código | Condição |
| --- | --- | --- |
| 400 | `INVALID_MULTIPART` | Corpo multipart malformado, campo de texto ou mais de uma parte |
| 413 | `PHOTO_TOO_LARGE` | Foto acima do limite de bytes |
| 413 | `REQUEST_TOO_LARGE` | Corpo inteiro acima do limite |
| 413 | `IMAGE_DIMENSIONS_TOO_LARGE` | Foto acima do limite de pixels |
| 415 | `UNSUPPORTED_REQUEST_TYPE` | Requisição com tipo diferente de multipart |
| 415 | `UNSUPPORTED_IMAGE_TYPE` | Tipo declarado ou formato decodificado diferente de JPEG |
| 422 | `PHOTO_REQUIRED` | Arquivo no campo `photo` ausente |
| 422 | `CORRUPT_IMAGE` | Os bytes da foto não podem ser decodificados |
| 422 | `NO_FACE` | Nenhum rosto encontrado |
| 422 | `MULTIPLE_FACES` | Mais de um rosto encontrado |

## Processamento de `hog-v1`

1. O Pillow valida o formato e as dimensões antes da decodificação e aplica a orientação EXIF. A imagem orientada é convertida para tons de cinza de 8 bits.
2. O OpenCV detecta rostos frontais com `haarcascade_frontalface_default.xml`, `scaleFactor=1.1`, `minNeighbors=5` e tamanho mínimo de `30×30` pixels. Para uma única detecção, o serviço recorta o retângulo facial e redimensiona para `64×64` com interpolação bilinear.
3. O HOG usa janela de `64×64`, blocos de `16×16`, passo de `8×8`, células de `8×8` e 9 intervalos de orientação sem sinal. A normalização é L2-Hys com limiar de `0.2`, sigma de `4.0`, abertura da derivada de `1`, 64 níveis e correção gama desativada. São `7×7` blocos com `2×2` células e 9 valores por célula, totalizando 1.764 valores. [Referência do OpenCV](https://docs.opencv.org/4.13.0/d5/d33/structcv_1_1HOGDescriptor.html)

Qualquer mudança no detector, no pré-processamento ou nos parâmetros que torne vetores incompatíveis exige uma nova `modelVersion`. Para renovar templates anteriores, recadastre a foto e o consentimento pelo fluxo oficial `POST /api/users/:id/face`. A captura aceita templates `hog-v1` com 1.764 componentes válidos.

## Reconhecimento por captura

O terminal envia `POST /api/access/face/capture` ao backend com `x-terminal-key`, `x-face-attempt-id` (UUID novo por tentativa) e de uma a três partes JPEG de nome `photos` em `multipart/form-data`. Cada arquivo pode ter até 102.400 bytes (ou o limite menor configurado no backend) e 4 milhões de pixels. O backend identifica o local pela chave e seleciona até 256 templates vinculados a ele.

Na chamada interna `POST /match`, o backend envia JSON de até 16 MiB com `photos` (JPEGs em Base64), `candidates` (objetos com `userId`, `embedding` e `modelVersion`), `minimumScore` e `minimumMargin`. O timeout do backend usa `FACE_RECOGNITION_TIMEOUT_MS`, com padrão de 5 segundos. O serviço reaproveita a extração do cadastro e compara os vetores por similaridade cosseno. Cada captura vota no melhor candidato quando atinge score de pelo menos 0,75 e vantagem de pelo menos 0,08 sobre o segundo, quando houver. Capturas sem identificação ficam sem voto. O candidato com mais votos vence se for o único líder. Um empate entre líderes resulta em `UNKNOWN_FACE`. O score devolvido em `MATCH` é o menor entre os votos do vencedor.

- `MATCH` inclui `userId` e `score`. O backend verifica esses dados, aplica as regras de autorização e devolve `allowed: true` somente se a decisão for `GRANTED`.
- `UNKNOWN_FACE` e `AMBIGUOUS_FACE` geram recusa. Um quadro sem rosto pode ser ignorado se outro contiver um rosto. Múltiplos rostos, JPEG inválido e dimensões excessivas invalidam o lote.
- O backend registra uma decisão por tentativa processada. Um UUID já processado para o mesmo terminal recebe `409 FACE_ATTEMPT_REPLAYED`. Uma nova captura iniciada pelo usuário usa outro UUID. Fotos de tentativa e embeddings ficam em memória durante o processamento.
- Os limiares são iniciais para a demonstração. Os testes locais usam uma foto pública, uma variação de brilho e vetores controlados. A calibração com pessoas distintas e imagens consentidas ainda precisa ser feita na bancada. O fluxo não implementa detecção de vivacidade.

Antes de usar a rota, aplique a migração com `npm run db:deploy` em `backend/`, apontado para o banco de teste.

## Executar e testar

A partir de `face-recognition/`, usando Python 3.13:

```sh
python -m pip install -r requirements-test.txt
python -m unittest discover -s tests -v
python -m uvicorn main:app
```

Os testes usam um recorte da foto de Eileen Collins publicada pela NASA em domínio público. A amostra fica no repositório para execução offline. [Origem da foto](https://scikit-image.org/docs/stable/api/skimage.data.html#skimage.data.astronaut)

Para rodar o contêiner isolado com a porta publicada apenas para teste local:

```sh
docker build -t face-recognition .
docker run --rm -p 127.0.0.1:8000:8000 face-recognition
```
