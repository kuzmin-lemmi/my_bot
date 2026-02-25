from __future__ import annotations

import logging
from datetime import date
from typing import Any

import aiohttp

logger = logging.getLogger(__name__)


class BackendAPIClient:
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.headers = {"Authorization": f"Bearer {token}"} if token else {}
    
    async def create_goal(self, title: str, target_date: str | None = None) -> dict[str, Any]:
        """Create a single goal"""
        url = f"{self.base_url}/api/goals"
        payload = {
            "title": title,
            "target_date": target_date or date.today().isoformat(),
            "source": "telegram",
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=payload, headers=self.headers) as resp:
                if resp.status == 200 or resp.status == 201:
                    return await resp.json()
                else:
                    error_text = await resp.text()
                    logger.error(f"Failed to create goal: {resp.status} {error_text}")
                    raise Exception(f"API error: {resp.status}")
    
    async def create_goals_batch(self, titles: list[str], target_date: str | None = None) -> dict[str, Any]:
        """Create multiple goals at once"""
        url = f"{self.base_url}/api/goals/batch"
        target = target_date or date.today().isoformat()
        
        items = [{"title": title, "target_date": target, "source": "telegram"} for title in titles]
        payload = {"items": items}
        
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=payload, headers=self.headers) as resp:
                if resp.status == 200 or resp.status == 201:
                    return await resp.json()
                else:
                    error_text = await resp.text()
                    logger.error(f"Failed to create batch: {resp.status} {error_text}")
                    raise Exception(f"API error: {resp.status}")
