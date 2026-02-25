#!/usr/bin/env python3
from __future__ import annotations

import asyncio
import logging
import os
import sys

from aiogram import Bot, Dispatcher
from dotenv import load_dotenv

from bot.api_client import BackendAPIClient
from bot.config import get_bot_config
from bot.handlers import setup_handlers

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


async def main():
    # Load environment variables
    load_dotenv()
    
    # Get configuration
    try:
        config = get_bot_config()
    except ValueError as e:
        logger.error(f"Configuration error: {e}")
        logger.error("Please set BOT_TOKEN environment variable")
        sys.exit(1)
    
    logger.info(f"Starting bot with backend at {config.backend_url}")
    
    # Initialize bot and dispatcher
    bot = Bot(token=config.bot_token)
    dp = Dispatcher()
    
    # Setup API client
    api_client = BackendAPIClient(config.backend_url, config.backend_token)
    
    # Register handlers
    router = setup_handlers(api_client)
    dp.include_router(router)
    
    # Start polling
    logger.info("Bot started. Press Ctrl+C to stop.")
    try:
        await dp.start_polling(bot)
    finally:
        await bot.session.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
