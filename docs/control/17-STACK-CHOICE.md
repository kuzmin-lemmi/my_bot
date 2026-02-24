# STACK CHOICE — рекомендуемый стек MVP

## Backend API
- Python 3.12+
- FastAPI

Почему:
- быстро для MVP
- хороший DX
- удобно для JSON API
- легко стыкуется с aiogram и SQLite

## Telegram Bot
- aiogram 3.x

## DB
- SQLite (v1)

## Доступ к БД (варианты)
- SQLAlchemy (более "правильно")
или
- aiosqlite / лёгкий repository layer (быстрее старт)

## Daily rollover
- cron/systemd timer на VPS + backend command/service
(для MVP проще и надёжнее)

## Mobile
- Flutter (Android-first)
- локальные уведомления через Flutter plugins (подбор на стороне UI-модели)

## Docker
- Не обязателен для первого запуска
- Добавить после рабочего MVP
