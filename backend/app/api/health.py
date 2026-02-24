from __future__ import annotations

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def healthcheck() -> dict[str, object]:
    return {
        "ok": True,
        "data": {
            "service": "mvp-control-backend",
            "status": "up",
        },
    }
