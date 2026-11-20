from io import BytesIO
from typing import Literal

from fastapi import FastAPI, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, FiniteFloat, Field
from python_multipart.exceptions import MultipartParseError
from starlette.datastructures import UploadFile
from starlette.formparsers import MultiPartException, MultiPartParser

from hog import EMBEDDING_SIZE, MODEL_VERSION, FaceCountError, extract_hog

MAX_PHOTO_BYTES = 102_400
MAX_REQUEST_BYTES = MAX_PHOTO_BYTES + 16_384
MAX_IMAGE_PIXELS = 4_000_000

app = FastAPI(title="Face Recognition")


class ExtractionResult(BaseModel):
    embedding: list[FiniteFloat] = Field(
        min_length=EMBEDDING_SIZE, max_length=EMBEDDING_SIZE
    )
    modelVersion: Literal[MODEL_VERSION]


def error(status: int, code: str) -> HTTPException:
    return HTTPException(status_code=status, detail={"code": code})


async def bounded_body(request: Request):
    total = 0
    async for chunk in request.stream():
        total += len(chunk)
        if total > MAX_REQUEST_BYTES:
            # The multipart parser closes partial uploads on MultiPartException.
            raise RequestTooLarge("Multipart body exceeds the configured limit.")
        yield chunk


class RequestTooLarge(MultiPartException):
    pass


def decode_jpeg(photo: bytes) -> Image.Image:
    try:
        with Image.open(BytesIO(photo)) as image:
            if image.format != "JPEG":
                raise error(415, "UNSUPPORTED_IMAGE_TYPE")
            if image.width * image.height > MAX_IMAGE_PIXELS:
                raise error(413, "IMAGE_DIMENSIONS_TOO_LARGE")
            return ImageOps.exif_transpose(image)
    except Image.DecompressionBombError as exc:
        raise error(413, "IMAGE_DIMENSIONS_TOO_LARGE") from exc
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError) as exc:
        raise error(422, "CORRUPT_IMAGE") from exc


def extract_photo(photo: bytes) -> ExtractionResult:
    with decode_jpeg(photo) as image:
        try:
            embedding = extract_hog(image)
        except FaceCountError as exc:
            code = "NO_FACE" if exc.count == 0 else "MULTIPLE_FACES"
            raise error(422, code) from exc
    return ExtractionResult(embedding=embedding, modelVersion=MODEL_VERSION)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post(
    "/extract",
    response_model=ExtractionResult,
    responses={
        400: {"description": "Malformed multipart or unexpected parts"},
        413: {"description": "Photo, request body or image dimensions exceed the limit"},
        415: {"description": "Expected multipart/form-data with an image/jpeg file"},
        422: {"description": "Missing or corrupt photo, no face or multiple faces"},
    },
    openapi_extra={
        "requestBody": {
            "required": True,
            "content": {
                "multipart/form-data": {
                    "schema": {
                        "type": "object",
                        "required": ["photo"],
                        "additionalProperties": False,
                        "properties": {"photo": {"type": "string", "format": "binary"}},
                    },
                    "encoding": {"photo": {"contentType": "image/jpeg"}},
                }
            },
        }
    },
)
async def extract(request: Request) -> ExtractionResult:
    media_type = request.headers.get("content-type", "").split(";", 1)[0]
    if media_type.strip().lower() != "multipart/form-data":
        raise error(415, "UNSUPPORTED_REQUEST_TYPE")

    parser = MultiPartParser(
        request.headers, bounded_body(request), max_files=1, max_fields=0
    )
    try:
        form = await parser.parse()
    except RequestTooLarge as exc:
        raise error(413, "REQUEST_TOO_LARGE") from exc
    except (MultiPartException, MultipartParseError) as exc:
        raise error(400, "INVALID_MULTIPART") from exc

    try:
        photo = form.get("photo")
        if not isinstance(photo, UploadFile):
            raise error(422, "PHOTO_REQUIRED")
        if photo.content_type != "image/jpeg":
            raise error(415, "UNSUPPORTED_IMAGE_TYPE")
        content = await photo.read(MAX_PHOTO_BYTES + 1)
        if len(content) > MAX_PHOTO_BYTES:
            raise error(413, "PHOTO_TOO_LARGE")
    finally:
        await form.close()

    return await run_in_threadpool(extract_photo, content)
