# API CONTRACT — единый контракт UI ↔ Backend

## Общие правила
- Любые изменения API сначала фиксируются в этом файле
- UI/Backend не делают тихих изменений полей
- Даты/время: ISO 8601
- Все ошибки имеют code (machine-readable)
- Single-user MVP: auth может быть упрощённый (временный токен/локальная схема)

## Статус контракта
- Версия: v1 (заморожена для MVP)
- Дата фиксации: 2026-02-24
- Правило: обратная несовместимость запрещена до завершения MVP

## Auth (single-user v1)
- Схема: `Authorization: Bearer <MVP_TOKEN>`
- Токен задаётся в backend через env (`MVP_TOKEN`)
- Mobile app хранит токен локально в настройках приложения
- Telegram webhook использует отдельный `X-Telegram-Secret` (env)
- При неверном/отсутствующем токене backend возвращает `UNAUTHORIZED`

## Форматы дат и времени
- `date`: `YYYY-MM-DD` (локальная дата пользователя)
- `time`: `HH:MM`
- `datetime`: ISO 8601 c timezone (`2026-02-24T18:30:00+01:00`)
- Все вычисления "today" делаются в timezone пользователя

## Формат ответа (рекомендуемый v1)
Успех:
{
  "ok": true,
  "data": ...
}

Ошибка:
{
  "ok": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "..."
  }
}

## DTO (v1)

Goal DTO:
{
  "id": 101,
  "title": "Проверить тетради 10А",
  "note": "Сначала 1 вариант",
  "target_date": "2026-02-24",
  "target_time": "18:30",
  "priority": "normal",
  "status": "active",
  "snooze_until": null,
  "created_from": "telegram",
  "last_reminded_at": null,
  "reminder_ignore_count": 0,
  "completed_at": null,
  "canceled_at": null,
  "created_at": "2026-02-24T09:00:00+01:00",
  "updated_at": "2026-02-24T09:00:00+01:00"
}

Goal Action Event DTO:
{
  "id": 501,
  "goal_id": 101,
  "action_type": "completed",
  "action_payload": {"source_action": "button_complete"},
  "source": "mobile",
  "created_at": "2026-02-24T18:42:00+01:00"
}

Reminder Policy DTO:
{
  "active_window_start": "09:00",
  "active_window_end": "21:00",
  "quiet_period_enabled": true,
  "quiet_period_start": "14:00",
  "quiet_period_end": "17:00",
  "interval_minutes": 30,
  "default_snooze_options": [10, 30, 60],
  "sound_enabled": true,
  "persistence_mode": "soft",
  "escalation_enabled": true,
  "escalation_step_minutes": 5,
  "global_pause_until": null,
  "ask_about_auto_moved_morning": true,
  "updated_at": "2026-02-24T09:00:00+01:00"
}

Calendar Day DTO:
{
  "date": "2026-02-24",
  "active": 3,
  "snoozed": 1,
  "completed": 2,
  "canceled": 0,
  "total": 6
}

---

## GOALS

### POST /api/goals
Создать одну цель

Request:
{
  "title": "Проверить тетради 10А",
  "note": "Сначала 1 вариант",
  "target_date": "2026-02-24",
  "target_time": "18:30",
  "priority": "normal",
  "source": "telegram"
}

Response:
{
  "ok": true,
  "data": {
    "goal": {Goal DTO}
  }
}

### POST /api/goals/batch
Создать несколько целей (например из Telegram сообщения по строкам)

Request:
{
  "items": [
    {"title": "Проверить 8Б", "target_date": "2026-02-24", "source": "telegram"},
    {"title": "Подготовить презентацию", "target_date": "2026-02-25", "source": "telegram"}
  ]
}

Response:
{
  "ok": true,
  "data": {
    "created_count": 2,
    "goals": [{Goal DTO}, {Goal DTO}]
  }
}

### GET /api/goals?date=2026-02-24
Получить цели на дату

Response:
{
  "ok": true,
  "data": {
    "date": "2026-02-24",
    "items": [{Goal DTO}]
  }
}

### GET /api/goals/calendar?month=2026-02
Получить агрегированные данные для календаря месяца

Response:
{
  "ok": true,
  "data": {
    "month": "2026-02",
    "days": [{Calendar Day DTO}]
  }
}

### PUT /api/goals/{id}
Редактировать цель

Response:
{
  "ok": true,
  "data": {
    "goal": {Goal DTO}
  }
}

### POST /api/goals/{id}/complete
Отметить выполненной

Request (optional):
{
  "confirmed": true
}

Response:
{
  "ok": true,
  "data": {
    "goal": {Goal DTO},
    "event": {Goal Action Event DTO}
  }
}

### POST /api/goals/{id}/snooze
Отложить цель

Request:
{
  "minutes": 30
}

Response:
{
  "ok": true,
  "data": {
    "goal": {Goal DTO},
    "event": {Goal Action Event DTO}
  }
}

### POST /api/goals/{id}/move-to-tomorrow
Перенести цель на завтра (та же задача, target_date += 1)

Response:
{
  "ok": true,
  "data": {
    "goal": {Goal DTO},
    "event": {Goal Action Event DTO}
  }
}

### POST /api/goals/{id}/cancel
Отменить цель

Request (optional):
{
  "confirmed": true
}

Response:
{
  "ok": true,
  "data": {
    "goal": {Goal DTO},
    "event": {Goal Action Event DTO}
  }
}

---

## REMINDER POLICY
### GET /api/reminder-policy

Response:
{
  "ok": true,
  "data": {
    "policy": {Reminder Policy DTO}
  }
}

### PUT /api/reminder-policy

Response:
{
  "ok": true,
  "data": {
    "policy": {Reminder Policy DTO}
  }
}

### POST /api/reminder-policy/global-pause

Request:
{
  "minutes": 30
}

Response:
{
  "ok": true,
  "data": {
    "policy": {Reminder Policy DTO}
  }
}

### POST /api/reminder-policy/global-pause/clear

Response:
{
  "ok": true,
  "data": {
    "policy": {Reminder Policy DTO}
  }
}

---

## JOURNAL / HISTORY
### GET /api/events?date=2026-02-24

Response:
{
  "ok": true,
  "data": {
    "date": "2026-02-24",
    "items": [{Goal Action Event DTO}]
  }
}

---

## TELEGRAM INTEGRATION (backend side)
### POST /api/telegram/webhook

Response:
{
  "ok": true,
  "data": {
    "processed": true
  }
}

---

## ERROR CODES (минимум)
- VALIDATION_ERROR
- NOT_FOUND
- CONFLICT_STATE
- BAD_TIME_WINDOW
- BAD_SNOOZE_OPTION
- UNAUTHORIZED
- INTERNAL_ERROR

## HTTP status mapping (v1)
- `200/201`: успех
- `400`: `VALIDATION_ERROR`, `BAD_TIME_WINDOW`, `BAD_SNOOZE_OPTION`
- `401`: `UNAUTHORIZED`
- `404`: `NOT_FOUND`
- `409`: `CONFLICT_STATE`
- `500`: `INTERNAL_ERROR`
