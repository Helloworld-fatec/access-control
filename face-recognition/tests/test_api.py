import unittest
from io import BytesIO
from math import isfinite
from pathlib import Path

from fastapi.testclient import TestClient
from PIL import Image

from main import MAX_PHOTO_BYTES, MAX_REQUEST_BYTES, app

ASTRONAUT = Path(__file__).with_name("astronaut.jpg")


def image_bytes(image_format="JPEG", size=(16, 16)):
    buffer = BytesIO()
    with Image.new("RGB", size) as image:
        image.save(buffer, format=image_format)
    return buffer.getvalue()


class ApiContractTest(unittest.TestCase):
    def setUp(self):
        self.client = self.enterContext(TestClient(app))

    def check_error(self, response, status, code):
        self.assertEqual(response.status_code, status)
        self.assertEqual(response.json(), {"detail": {"code": code}})

    def upload(self, content, media_type="image/jpeg", field="photo"):
        return self.client.post(
            "/extract", files={field: ("photo.jpg", content, media_type)}
        )

    def test_health(self):
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    def test_openapi_declares_upload_and_result(self):
        response = self.client.get("/openapi.json")
        self.assertEqual(response.status_code, 200)
        spec = response.json()
        operation = spec["paths"]["/extract"]["post"]
        multipart = operation["requestBody"]["content"]["multipart/form-data"]
        self.assertEqual(multipart["schema"]["required"], ["photo"])
        self.assertIn("200", operation["responses"])
        result = spec["components"]["schemas"]["ExtractionResult"]
        self.assertEqual(set(result["required"]), {"embedding", "modelVersion"})

    def test_single_face_returns_a_repeatable_hog_vector(self):
        photo = ASTRONAUT.read_bytes()
        response = self.upload(photo)
        self.assertEqual(response.status_code, 200, response.text)
        result = response.json()
        self.assertEqual(result["modelVersion"], "hog-v1")
        embedding = result["embedding"]
        self.assertEqual(len(embedding), 1764)
        self.assertTrue(all(isfinite(value) for value in embedding))
        self.assertTrue(any(value > 0 for value in embedding))
        self.assertEqual(self.upload(photo).json(), result)

    def test_corrects_exif_orientation(self):
        buffer = BytesIO()
        with Image.open(ASTRONAUT) as image:
            exif = Image.Exif()
            exif[274] = 6
            image.transpose(Image.Transpose.ROTATE_90).save(
                buffer, format="JPEG", exif=exif
            )
        response = self.upload(buffer.getvalue())
        self.assertEqual(response.status_code, 200, response.text)

    def test_rejects_photo_without_a_face(self):
        self.check_error(self.upload(image_bytes(size=(128, 128))), 422, "NO_FACE")

    def test_rejects_photo_with_multiple_faces(self):
        buffer = BytesIO()
        with Image.open(ASTRONAUT) as face:
            with Image.new("RGB", (2 * face.width + 32, face.height)) as collage:
                collage.paste(face, (0, 0))
                collage.paste(face, (face.width + 32, 0))
                collage.save(buffer, format="JPEG")
        self.check_error(self.upload(buffer.getvalue()), 422, "MULTIPLE_FACES")

    def test_missing_photo_field(self):
        self.check_error(self.upload(image_bytes(), field="other"), 422, "PHOTO_REQUIRED")

    def test_requires_multipart(self):
        self.check_error(
            self.client.post("/extract", json={}), 415, "UNSUPPORTED_REQUEST_TYPE"
        )

    def test_rejects_duplicate_photo_parts(self):
        photo = ("photo.jpg", image_bytes(), "image/jpeg")
        response = self.client.post("/extract", files=[("photo", photo), ("photo", photo)])
        self.check_error(response, 400, "INVALID_MULTIPART")

    def test_rejects_malformed_multipart(self):
        response = self.client.post(
            "/extract", headers={"content-type": "multipart/form-data"}
        )
        self.check_error(response, 400, "INVALID_MULTIPART")

    def test_requires_jpeg_type(self):
        self.check_error(self.upload(image_bytes(), "image/png"), 415, "UNSUPPORTED_IMAGE_TYPE")
        self.check_error(self.upload(image_bytes("PNG")), 415, "UNSUPPORTED_IMAGE_TYPE")

    def test_rejects_corrupt_jpeg(self):
        self.check_error(self.upload(image_bytes()[:-20]), 422, "CORRUPT_IMAGE")

    def test_rejects_oversized_photo(self):
        self.check_error(self.upload(b"x" * (MAX_PHOTO_BYTES + 1)), 413, "PHOTO_TOO_LARGE")

    def test_rejects_oversized_request(self):
        self.check_error(self.upload(b"x" * MAX_REQUEST_BYTES), 413, "REQUEST_TOO_LARGE")

    def test_rejects_oversized_dimensions(self):
        jpeg = image_bytes(size=(2001, 2000))
        self.check_error(self.upload(jpeg), 413, "IMAGE_DIMENSIONS_TOO_LARGE")
