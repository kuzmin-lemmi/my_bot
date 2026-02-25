# Telegram Bot (Stage 4)

Telegram бот для быстрого добавления целей через мессенджер.

## Функции

- `/start` — приветствие и инструкция
- `/help` — справка по использованию
- Текстовое сообщение → цель на сегодня
- Многострочное сообщение → batch создание целей

## Установка

1. Установите зависимости:
   ```bash
   pip install -r requirements.txt
   ```

2. Создайте бота в Telegram через [@BotFather](https://t.me/BotFather)

3. Скопируйте `.env.example` в `.env` и заполните:
   ```bash
   BOT_TOKEN=your_telegram_bot_token_here
   BACKEND_URL=http://localhost:8000
   MVP_TOKEN=your_backend_token
   ```

## Запуск

### Запустить backend (в одном терминале):
```bash
cd backend
uvicorn app.main:app --reload
```

### Запустить бота (в другом терминале):
```bash
cd backend
python -m bot.main
```

## Использование

1. Найдите бота в Telegram по username
2. Отправьте `/start`
3. Отправьте текстовое сообщение — оно станет целью на сегодня
4. Отправьте многострочное сообщение — каждая строка станет отдельной целью

### Примеры

**Одна цель:**
```
Проверить тетради 10А
```

**Несколько целей:**
```
Проверить 8Б
Подготовить план урока
Купить молоко
```

## Архитектура

```
bot/
├── __init__.py
├── main.py          # Entry point, bot initialization
├── config.py        # Configuration from env
├── api_client.py    # Backend API client
├── handlers.py      # Message handlers (/start, /help, text)
└── README.md
```

## Интеграция с backend

Бот использует backend API endpoints:
- `POST /api/goals` — создание одной цели
- `POST /api/goals/batch` — создание нескольких целей
- Авторизация через `Authorization: Bearer {MVP_TOKEN}`

## Логирование

Бот логирует все действия:
- Созданные цели
- Ошибки API
- Сообщения пользователей

Уровень логирования: `INFO`
