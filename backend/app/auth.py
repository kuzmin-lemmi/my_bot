from __future__ import annotations

from fastapi import Header

from app.config import get_settings
from app.errors import APIError


def require_auth(authorization: str | None = Header(default=None)) -> None:
    settings = get_settings()
    if not settings.mvp_token:
        return

    if not authorization or not authorization.startswith("Bearer "):
        raise APIError("UNAUTHORIZED", "Missing or invalid Authorization header", 401)

    token = authorization.removeprefix("Bearer ").strip()
    if token != settings.mvp_token:
        raise APIError("UNAUTHORIZED", "Invalid token", 401)
