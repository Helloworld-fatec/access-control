"""
Reconhecimento facial com descritor HOG (sem deep learning).

Pipeline:
  1. Detecta o rosto (Haar Cascade do OpenCV).
  2. Recorta, converte para cinza, equaliza o histograma e redimensiona p/ 96x96.
  3. Calcula o HOG (9 orientações, células 8x8, blocos 16x16) -> vetor de 4356 dims.
  4. Centraliza e normaliza o vetor (equivale a correlação de Pearson ao comparar).
  5. Match = maior similaridade entre o rosto da webcam e os descritores cadastrados.

No cadastro geramos várias variações do rosto (pequenos deslocamentos, escala e
espelhamento) para o HOG tolerar o "tremido" da caixa do detector.
"""
import threading

import cv2
import numpy as np

FACE_SIZE = 96
_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
# winSize, blockSize, blockStride, cellSize, nbins
_hog = cv2.HOGDescriptor((FACE_SIZE, FACE_SIZE), (16, 16), (8, 8), (8, 8), 9)
_lock = threading.Lock()  # CascadeClassifier não é thread-safe


def detect_faces(gray, min_size=60):
    """Retorna lista de (x, y, w, h)."""
    eq = cv2.equalizeHist(gray)
    with _lock:
        faces = _cascade.detectMultiScale(eq, scaleFactor=1.1, minNeighbors=5,
                                          minSize=(min_size, min_size))
    return [tuple(int(v) for v in f) for f in faces]


def _crop(gray, box, dx=0.0, dy=0.0, scale=1.0, flip=False):
    x, y, w, h = box
    side = max(8, int(round(max(w, h) * 1.1 * scale)))
    cx, cy = x + w / 2 + dx * w, y + h / 2 + dy * h
    patch = cv2.getRectSubPix(gray, (side, side), (cx, cy))
    patch = cv2.resize(patch, (FACE_SIZE, FACE_SIZE), interpolation=cv2.INTER_AREA)
    if flip:
        patch = cv2.flip(patch, 1)
    return cv2.equalizeHist(patch)


def _embed(face96):
    with _lock:
        v = _hog.compute(face96).flatten().astype(np.float32)
    v -= v.mean()
    return v / (np.linalg.norm(v) + 1e-8)


def embedding(gray, box):
    """Embedding HOG de um rosto (vetor unitário, 4356 dims)."""
    return _embed(_crop(gray, box))


def enroll_embeddings(gray, box):
    """Matriz (N, 4356) com variações do rosto cadastrado."""
    vecs = []
    for flip in (False, True):
        for scale in (0.92, 1.0, 1.08):
            for dx in (-0.05, 0.0, 0.05):
                for dy in (-0.05, 0.0, 0.05):
                    vecs.append(_embed(_crop(gray, box, dx, dy, scale, flip)))
    return np.stack(vecs)


def similarity(bank, vec):
    """Maior correlação entre o vetor e o banco de embeddings (-1..1)."""
    return float(np.max(bank @ vec))


def hog_visual(gray, box, cell=8, bins=9, scale=5):
    """Imagem para visualizar o HOG do rosto (linhas = orientação das bordas)."""
    face = _crop(gray, box).astype(np.float32)
    gx = cv2.Sobel(face, cv2.CV_32F, 1, 0, ksize=1)
    gy = cv2.Sobel(face, cv2.CV_32F, 0, 1, ksize=1)
    mag, ang = cv2.cartToPolar(gx, gy, angleInDegrees=True)
    ang = ang % 180
    n = FACE_SIZE // cell
    img = np.zeros((n * cell * scale, n * cell * scale), np.uint8)
    for i in range(n):
        for j in range(n):
            sl = (slice(i * cell, (i + 1) * cell), slice(j * cell, (j + 1) * cell))
            hist, _ = np.histogram(ang[sl].ravel(), bins=bins, range=(0, 180),
                                   weights=mag[sl].ravel())
            hist = hist / (hist.max() + 1e-8)
            cx, cy = (j + 0.5) * cell * scale, (i + 0.5) * cell * scale
            for b, hv in enumerate(hist):
                theta = np.deg2rad((b + 0.5) * 180 / bins + 90)
                r = hv * cell * scale / 2
                dx, dy = np.cos(theta) * r, np.sin(theta) * r
                cv2.line(img, (int(cx - dx), int(cy - dy)), (int(cx + dx), int(cy + dy)),
                         int(70 + 185 * hv), 1, cv2.LINE_AA)
    return img
