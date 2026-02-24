from __future__ import annotations

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class APIError(Exception):
    def __init__(self, code: str, message: str, status_code: int) -> None:
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(message)


def error_payload(code: str, message: str) -> dict[str, object]:
    return {
        "ok": False,
        "error": {
            "code": code,
            "message": message,
        },
    }


async def api_error_handler(_: Request, exc: Exception) -> JSONResponse:
    if not isinstance(exc, APIError):
        return JSONResponse(
            status_code=500,
            content=error_payload("INTERNAL_ERROR", "Unexpected error"),
        )
    return JSONResponse(
        status_code=exc.status_code,
        content=error_payload(exc.code, exc.message),
    )


async def request_validation_error_handler(_: Request, exc: Exception) -> JSONResponse:
    if isinstance(exc, RequestValidationError):
        message = exc.errors()[0].get("msg", "Invalid request") if exc.errors() else "Invalid request"
    else:
        message = "Invalid request"
    return JSONResponse(
        status_code=400,
        content=error_payload("VALIDATION_ERROR", message),
    )
