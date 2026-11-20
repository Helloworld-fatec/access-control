# Reconhecimento facial com HOG

Python (`http.server`) + HTML/CSS/JS puros. Sem deep learning: o "embedding" é o descritor HOG do rosto.

## Rodar
```bash
pip install -r requirements.txt   # OpenCV 4.x (o 5.0 removeu o CascadeClassifier)
python server.py          # ou: python server.py 9000
```
Abra http://localhost:8000 (a webcam só funciona em `localhost` ou HTTPS).

## Como usar
1. Envie uma foto frontal (clique ou arraste). O servidor detecta o rosto, extrai o HOG (4356 dims) e mostra a visualização.
2. Clique em **Abrir webcam**. O rosto é comparado a cada frame; caixa verde + banner "MATCH" quando o score >= limiar.
3. Ajuste o **limiar** no slider se tiver falso positivo (suba) ou não reconhecer (desça).

## Como funciona
- Detecção: Haar Cascade (OpenCV).
- Embedding: recorte 96x96 em cinza + equalização -> HOG (9 bins, células 8x8, blocos 16x16) -> centralizado e normalizado.
- Cadastro gera 54 variações (deslocamento, escala, espelho) para tolerar o tremido da caixa.
- Score = maior correlação entre o rosto da webcam e as variações cadastradas.

## Limitações
HOG é bem mais sensível a pose, iluminação e expressão do que embeddings de redes neurais. Use rosto frontal e luz parecida.
