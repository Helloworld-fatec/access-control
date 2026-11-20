# Face Recognition

Serviço interno em Python/FastAPI para extrair um descritor HOG de uma foto com um rosto. Na etapa de integração, o Express enviará a foto e associará o descritor retornado ao usuário.

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

Qualquer mudança no detector, no pré-processamento ou nos parâmetros que torne vetores incompatíveis exige uma nova `modelVersion`. O contrato atual do Express espera 128 valores de outro extrator. A integração deve validar a dimensão de 1.764 para `hog-v1`.

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
