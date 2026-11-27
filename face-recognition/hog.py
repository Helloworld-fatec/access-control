from pathlib import Path

import cv2
import numpy as np
from PIL import Image

MODEL_VERSION = "hog-v1"
EMBEDDING_SIZE = 1764
FACE_SIZE = (64, 64)
CASCADE_PATH = Path(cv2.data.haarcascades) / "haarcascade_frontalface_default.xml"


class FaceCountError(Exception):
    def __init__(self, count: int):
        self.count = count
        super().__init__(f"Expected one face, detected {count}")


def extract_hog(image: Image.Image) -> list[float]:
    gray = image.convert("L")
    detector = cv2.CascadeClassifier(str(CASCADE_PATH))
    if detector.empty():
        raise RuntimeError("Could not load the frontal face cascade")
    faces = detector.detectMultiScale(
        np.asarray(gray), scaleFactor=1.1, minNeighbors=5, minSize=(30, 30)
    )
    if len(faces) != 1:
        raise FaceCountError(len(faces))

    x, y, width, height = faces[0]
    crop = gray.crop((x, y, x + width, y + height))
    resized = crop.resize(FACE_SIZE, Image.Resampling.BILINEAR)
    hog = cv2.HOGDescriptor(
        FACE_SIZE, (16, 16), (8, 8), (8, 8), 9,
        1, 4.0, cv2.HOGDescriptor_L2Hys, 0.2, False, 64, False,
    )
    return hog.compute(np.asarray(resized)).ravel().tolist()
