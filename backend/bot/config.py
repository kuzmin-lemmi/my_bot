from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class BotConfig:
    bot_token: str
    backend_url: str
    backend_token: str


def get_bot_config() -> BotConfig:
    bot_token = os.getenv("BOT_TOKEN")
    if not bot_token:
        raise ValueError("BOT_TOKEN environment variable is required")
    
    backend_url = os.getenv("BACKEND_URL", "http://localhost:8000")
    backend_token = os.getenv("MVP_TOKEN", "")
    
    return BotConfig(
        bot_token=bot_token,
        backend_url=backend_url,
        backend_token=backend_token,
    )
