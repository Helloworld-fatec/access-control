import json
from base64 import b64decode
from binascii import Error as Base64Error
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
from matching import match_faces

MAX_PHOTO_BYTES = 102_400
MAX_REQUEST_BYTES = MAX_PHOTO_BYTES + 16_384
MAX_IMAGE_PIXELS = 4_000_000
MAX_CAPTURE_PHOTOS = 3
MAX_CANDIDATES = 256
MAX_MATCH_BYTES = 16 * 1024 * 1024
MAX_ENCODED_PHOTO_BYTES = ((MAX_PHOTO_BYTES + 2) // 3) * 4

app = FastAPI(title="Face Recognition")


class ExtractionResult(BaseModel):
    embedding: list[FiniteFloat] = Field(
        min_length=EMBEDDING_SIZE, max_length=EMBEDDING_SIZE
    )
    modelVersion: Literal[MODEL_VERSION]


class Candidate(ExtractionResult):
    userId: str = Field(min_length=1, max_length=64)


class MatchRequest(BaseModel):
    photos: list[str] = Field(min_length=1, max_length=MAX_CAPTURE_PHOTOS)
    candidates: list[Candidate] = Field(min_length=1, max_length=MAX_CANDIDATES)
    minimumScore: FiniteFloat = Field(gt=0, le=1)
    minimumMargin: FiniteFloat = Field(gt=0, le=1)


class MatchResult(BaseModel):
    result: Literal["MATCH", "UNKNOWN_FACE", "AMBIGUOUS_FACE"]
    userId: str | None = None
    score: FiniteFloat | None = None


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

def recognize_batch(request: MatchRequest) -> MatchResult:
    candidates = {candidate.userId: candidate.embedding for candidate in request.candidates}
    if len(candidates) != len(request.candidates):
        raise error(400, "INVALID_MATCH_REQUEST")

    captures = []
    for encoded in request.photos:
        if len(encoded) > MAX_ENCODED_PHOTO_BYTES:
            raise error(413, "PHOTO_TOO_LARGE")
        try:
            photo = b64decode(encoded, validate=True)
        except (ValueError, Base64Error) as exc:
            raise error(422, "CORRUPT_IMAGE") from exc
        if len(photo) > MAX_PHOTO_BYTES:
            raise error(413, "PHOTO_TOO_LARGE")
        try:
            captures.append(extract_photo(photo).embedding)
        except HTTPException as exc:
            if exc.detail != {"code": "NO_FACE"}:
                raise

    if not captures:
        raise error(422, "NO_FACE")

    try:
        result, user_id, score = match_faces(
            candidates, captures, request.minimumScore, request.minimumMargin
        )
    except ValueError as exc:
        raise error(400, "INVALID_MATCH_REQUEST") from exc
    return MatchResult(result=result, userId=user_id, score=score)


def parse_match_request(body: bytearray) -> MatchResult:
    try:
        dto = MatchRequest.model_validate(json.loads(body))
    except (ValueError, RecursionError) as exc:
        raise error(400, "INVALID_MATCH_REQUEST") from exc
    return recognize_batch(dto)


@app.post("/match", response_model=MatchResult, response_model_exclude_none=True)
async def match(request: Request) -> MatchResult:
    media_type = request.headers.get("content-type", "").split(";", 1)[0]
    if media_type.strip().lower() != "application/json":
        raise error(415, "UNSUPPORTED_REQUEST_TYPE")

    body = bytearray()
    async for chunk in request.stream():
        if len(body) + len(chunk) > MAX_MATCH_BYTES:
            raise error(413, "REQUEST_TOO_LARGE")
        body.extend(chunk)
    return await run_in_threadpool(parse_match_request, body)
