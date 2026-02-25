# FocusDay MVP — Система управления целями с настойчивыми напоминаниями

**Статус**: MVP завершён (Этапы 0-8)

FocusDay — это приложение для управления целями дня с автоматическими напоминаниями, которые помогают довести дела до конца. Single-user MVP для создателя продукта.

---

## Архитектура

### Backend (Python + FastAPI)
- **API**: RESTful endpoints для управления целями и настройками
- **База данных**: SQLite (локальная для MVP)
- **Авторизация**: Bearer token

### Mobile (Flutter + Android)
- **UI**: Material Design 3
- **State Management**: Provider
- **Notifications**: flutter_local_notifications
- **Platform**: Android-first (API 21+)

### Telegram Bot (aiogram 3.x)
- Быстрое добавление целей текстом
- Batch-режим для нескольких целей

---

## Быстрый старт

### 1. Backend

```bash
cd backend

# Установка зависимостей
pip install -r requirements.txt

# Настройка .env
cp .env.example .env
# Отредактируйте MVP_TOKEN и BOT_TOKEN

# Запуск сервера
uvicorn app.main:app --reload
```

Backend будет доступен на `http://localhost:8000`.

**Проверка**: `curl http://localhost:8000/health`

### 2. Telegram Bot (опционально)

```bash
cd backend

# Запуск бота
python -m bot.main
```

Отправьте `/start` в Telegram, чтобы протестировать.

### 3. Mobile App

```bash
cd mobile

# Установка зависимостей
flutter pub get

# Настройка подключения к Backend
# Отредактируйте lib/main.dart:
# - baseUrl (для эмулятора: http://10.0.2.2:8000)
# - token (ваш MVP_TOKEN)

# Запуск приложения
flutter run
```

---

## Основные функции

### Управление целями
- **Создание**: через Telegram или Mobile UI
- **Статусы**: active, snoozed, completed, canceled
- **Действия**: Выполнено, Отложить, На завтра, Отменить

### Напоминания
- Повторные уведомления по интервалу (по умолчанию 30 минут)
- Настраиваемое рабочее окно (09:00 - 21:00)
- Тихий час (опционально, 14:00 - 17:00)
- Глобальная пауза (на N минут)
- Эскалация (уменьшение интервала при игноре)

### Автоматизация
- **Daily Rollover**: автоперенос невыполненных целей на следующий день (`POST /api/goals/rollover`)
- **Фоновая синхронизация**: пересоздание расписания уведомлений при изменениях

### Календарь и аналитика
- Просмотр активности по месяцам
- Журнал событий (создание, переносы, выполнение)
- Статистика по дням

---

## Структура проекта

```
mvp_control/
├── backend/
│   ├── app/
│   │   ├── api/            # API endpoints
│   │   │   ├── goals.py
│   │   │   ├── reminder_policy.py
│   │   │   └── health.py
│   │   ├── db.py           # Database init & schema
│   │   ├── auth.py         # Bearer token auth
│   │   ├── config.py       # Settings
│   │   └── main.py         # FastAPI app
│   ├── bot/
│   │   ├── main.py         # Telegram bot entry
│   │   ├── handlers.py     # Commands & messages
│   │   └── api_client.py   # Backend API client
│   ├── data/               # SQLite database (ignored)
│   ├── requirements.txt
│   └── .env.example
├── mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/         # Goal, ReminderPolicy, Event
│   │   ├── services/       # ApiService, NotificationService
│   │   ├── providers/      # GoalProvider, PolicyProvider
│   │   ├── screens/        # UI screens
│   │   └── widgets/        # Reusable widgets
│   ├── android/
│   │   └── app/
│   │       └── src/main/AndroidManifest.xml
│   ├── pubspec.yaml
│   ├── DEPLOYMENT.md       # Руководство по деплою
│   └── README.md
└── docs/
    └── control/            # Спецификации и контракты
        ├── 04-API-CONTRACT.md
        ├── 05-STATE-MACHINE.md
        ├── 08-NOTIFICATION-SPEC.md
        └── 13-TASKS-BACKLOG.md
```

---

## API Endpoints

### Goals
- `POST /api/goals` — создать цель
- `POST /api/goals/batch` — создать несколько целей
- `GET /api/goals?date=YYYY-MM-DD` — список целей за день
- `PUT /api/goals/{id}` — обновить цель
- `POST /api/goals/{id}/complete` — выполнить
- `POST /api/goals/{id}/snooze` — отложить (minutes)
- `POST /api/goals/{id}/move-to-tomorrow` — перенести на завтра
- `POST /api/goals/{id}/cancel` — отменить
- `POST /api/goals/rollover` — автоперенос просроченных целей
- `GET /api/goals/calendar?month=YYYY-MM` — статистика по месяцу
- `GET /api/events?date=YYYY-MM-DD` — журнал событий

### Reminder Policy
- `GET /api/reminder-policy` — получить настройки напоминаний
- `PUT /api/reminder-policy` — обновить настройки
- `POST /api/reminder-policy/global-pause` — установить паузу (minutes)
- `POST /api/reminder-policy/global-pause/clear` — снять паузу

### Health
- `GET /health` — проверка работоспособности

**Авторизация**: `Authorization: Bearer <MVP_TOKEN>`

---

## Этапы разработки

- ✅ **Этап 0**: Фиксация спецификаций (API, State Machine, Schema)
- ✅ **Этап 1**: Backend каркас (FastAPI, SQLite, Auth)
- ✅ **Этап 2**: Goals API (CRUD + state transitions)
- ✅ **Этап 3**: Reminder Policy + Calendar + Events
- ✅ **Этап 4**: Telegram Bot (aiogram, text → goals)
- ✅ **Этап 5**: Mobile UI (Flutter screens, API integration)
- ✅ **Этап 6**: Daily Rollover (AUTO_MOVE_TO_TOMORROW)
- ✅ **Этап 7**: Local Notifications (Android, scheduling logic)
- ✅ **Этап 8**: Финальная полировка (деплой, документация)

---

## Следующие шаги

### Тестирование
1. Установить Mobile App на реальное устройство
2. Создать 3-5 целей на сегодня
3. Протестировать уведомления (проверить timing, quiet period, global pause)
4. Проверить все действия (Complete, Snooze, Move, Cancel)
5. Протестировать rollover (запустить на следующий день)

### Улучшения (Post-MVP)
- **Рефакторинг Backend**: разделить `goals.py` на слои (models/domain/api)
- **Unit-тесты**: покрыть тестами критичные сценарии (state transitions, rollover)
- **iOS Support**: адаптировать Flutter app под iOS
- **Multi-user**: добавить регистрацию и аутентификацию пользователей
- **Cloud Backend**: деплой на VPS/Cloud (Railway, Heroku, AWS)
- **Push Notifications**: интегрировать FCM для удалённых уведомлений
- **Analytics**: добавить трекинг использования (Firebase Analytics, Sentry)

---

## Технологии

**Backend**:
- Python 3.10+
- FastAPI 0.116+
- SQLite
- aiogram 3.13+ (Telegram Bot)

**Mobile**:
- Flutter 3.0+
- Dart 3.0+
- Provider (State Management)
- flutter_local_notifications
- workmanager (Background tasks)
- table_calendar

---

## Лицензия

Proprietary — Single-user MVP для внутреннего использования создателем продукта.

---

## Контакты

**GitHub**: https://github.com/kuzmin-lemmi/my_bot

**Поддержка**: Открывайте Issues на GitHub для багов или вопросов.

---

Создано с использованием Claude (Anthropic) — Logic/Backend AI Agent.
