from __future__ import annotations

import logging

from aiogram import Router
from aiogram.filters import Command
from aiogram.types import Message

from bot.api_client import BackendAPIClient

logger = logging.getLogger(__name__)
router = Router()


def setup_handlers(api_client: BackendAPIClient) -> Router:
    """Setup all bot handlers with API client"""
    
    @router.message(Command("start"))
    async def cmd_start(message: Message):
        """Handle /start command"""
        await message.answer(
            "Привет! Я бот для быстрого добавления важных дел.\n\n"
            "Просто отправь мне текст — и он станет целью на сегодня.\n"
            "Можешь отправить несколько строк — каждая станет отдельной целью.\n\n"
            "Команды:\n"
            "/start — это сообщение\n"
            "/help — справка"
        )
    
    @router.message(Command("help"))
    async def cmd_help(message: Message):
        """Handle /help command"""
        await message.answer(
            "Как пользоваться ботом:\n\n"
            "1️⃣ Отправь одну строку → одна цель на сегодня\n"
            "   Пример: Проверить тетради 10А\n\n"
            "2️⃣ Отправь несколько строк → несколько целей\n"
            "   Пример:\n"
            "   Проверить 8Б\n"
            "   Подготовить план урока\n"
            "   Купить молоко\n\n"
            "Все цели автоматически попадают в приложение на сегодня.\n"
            "Приложение будет напоминать о них в течение дня."
        )
    
    @router.message()
    async def handle_text(message: Message):
        """Handle all text messages - create goals"""
        if not message.text:
            await message.answer("Пришли текстовое сообщение с целью")
            return
        
        text = message.text.strip()
        if not text:
            await message.answer("Сообщение пустое")
            return
        
        lines = [line.strip() for line in text.split("\n") if line.strip()]
        
        if not lines:
            await message.answer("Не удалось извлечь цели из сообщения")
            return
        
        try:
            if len(lines) == 1:
                # Single goal
                result = await api_client.create_goal(lines[0])
                await message.answer(
                    f"✅ Цель добавлена на сегодня:\n{lines[0]}"
                )
                logger.info(f"Created single goal for user {message.from_user.id}: {lines[0]}")
            else:
                # Multiple goals (batch)
                result = await api_client.create_goals_batch(lines)
                count = result.get("data", {}).get("created_count", len(lines))
                goals_text = "\n".join(f"• {line}" for line in lines)
                await message.answer(
                    f"✅ Добавлено целей на сегодня: {count}\n\n{goals_text}"
                )
                logger.info(f"Created {count} goals for user {message.from_user.id}")
        except Exception as e:
            logger.error(f"Failed to create goals: {e}", exc_info=True)
            await message.answer(
                "❌ Не удалось добавить цели. Попробуй позже или проверь, что backend запущен."
            )
    
    return router
