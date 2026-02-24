from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    app_name: str
    app_env: str
    db_path: Path
    mvp_token: str
    telegram_secret: str


def get_settings() -> Settings:
    db_path_raw = os.getenv("DB_PATH", "data/mvp_control.db")
    db_path = Path(db_path_raw)
    if not db_path.is_absolute():
        db_path = (Path.cwd() / db_path).resolve()

    return Settings(
        app_name=os.getenv("APP_NAME", "mvp-control-backend"),
        app_env=os.getenv("APP_ENV", "dev"),
        db_path=db_path,
        mvp_token=os.getenv("MVP_TOKEN", ""),
        telegram_secret=os.getenv("TELEGRAM_SECRET", ""),
    )
