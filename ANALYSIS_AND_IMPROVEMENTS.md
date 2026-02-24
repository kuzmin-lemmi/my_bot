# АНАЛИЗ И УЛУЧШЕНИЯ ПРОЕКТА (этапы 0-2)

## ТЕКУЩЕЕ СОСТОЯНИЕ

### Реализовано
- ✅ Этап 0: Спецификации заморожены (API v1, State Machine, Auth, Schema)
- ✅ Этап 1: Backend каркас (FastAPI, SQLite init, seed policy)
- ✅ Этап 2: Goals API core (create, batch, actions, state transitions, events)

### Статистика кода
```
backend/app/api/goals.py      483 строк (монолит)
backend/app/db.py             179 строк (инит и миграции)
backend/app/main.py            34 строк (bootstrap)
backend/app/auth.py            19 строк (Bearer token)
TOTAL:                         715 строк
```

---

## АНАЛИЗ ПРОБЛЕМ

### TIER 1: КРИТИЧЕСКИЕ (влияют на корректность)

#### 1.1 Race condition в SNOOZE_EXPIRED
**Описание:**
```python
# goals.py:162-182
if row["status"] != "snoozed" or not row["snooze_until"]:
    return row
# <- Между проверкой и обновлением другой процесс может изменить статус
connection.execute("UPDATE goals SET status = 'active'...")
```

**Проблема:** Lost update - два процесса могут одновременно обновить цель

**Решение:** ✅ APPLIED
- Добавил `AND status = 'snoozed'` в WHERE clause
- UPDATE становится атомарной операцией

**Риск:**
- Medium (возникает только при concurrent requests)
- Низкий для single-user MVP, но важно для production

---

#### 1.2 Отсутствие batch transaction handling
**Описание:**
```python
# goals.py:250-270
rows = [_create_goal(connection, user_id, item) for item in payload.items]
# Если 8-я цель упадёт, уже созданы 7, 1-я + 2-я не откатятся
```

**Проблема:** Partial batch create — data inconsistency

**Решение:** ✅ APPLIED
- Обернул весь цикл в try-except
- При ошибке поднимается APIError (имплицит rollback)

**Улучшение:** Стоит явно вызвать `connection.rollback()` для ясности

---

#### 1.3 Отсутствие валидации time windows
**Описание:** 
```
Можно установить:
- active_window_start = 21:00, end = 09:00 (ошибка)
- quiet_period не внутри active_window (ошибка)
- quiet_enabled=true, но quiet_start=null (ошибка)
```

**Проблема:** Notification Spec нарушается, уведомления не работают корректно

**Решение:** ✅ APPLIED
- Добавил `_validate_time_windows()` функцию
- Проверяет все 5 правил (start<end, quiet внутри, и т.д.)
- Готов к использованию в этапе 3 (GET/PUT reminder-policy)

**Статус:** Функция написана, но не интегрирована в routes (это этап 3)

---

### TIER 2: АРХИТЕКТУРНЫЕ (влияют на maintainability)

#### 2.1 Монолитный goals.py (483 строк)
**Проблема:**
- Одновременно: DTO + валидация + SQL + бизнес-логика + HTTP handlers
- Сложно тестировать (нужен мок connection)
- Невозможно переиспользовать в Telegram-боте (этап 4)

**Текущие слои:**
```
goals.py:
├── DTO-модели (GoalCreateIn, SnoozeIn, etc.)  ← models/goal.py
├── Валидаторы (_normalize_title, _validate_time_windows, etc.) ← domain/validators.py
├── БД-операции (_create_goal, _fetch_goal, _apply_snooze_expired, etc.) ← domain/goal_repository.py
├── Бизнес-логика (complete, snooze, move_to_tomorrow) ← domain/goal_service.py
└── HTTP handlers (@router.post, @router.get, etc.) ← api/goals.py
```

**Рекомендуемая структура:**
```
backend/app/
├── models/
│   ├── goal.py        (GoalCreateIn, GoalUpdateIn, Goal, etc.)
│   └── __init__.py
├── domain/
│   ├── validators.py  (_validate_time_windows, etc.)
│   ├── goal_repository.py (DB access layer, CRUD)
│   ├── goal_service.py (complete, snooze, move, cancel - чистая бизнес-логика)
│   └── __init__.py
├── api/
│   ├── goals.py      (10-20 строк: handlers + dependency injection)
│   ├── health.py
│   └── __init__.py
└── main.py
```

**Преимущества:**
- Unit-тесты для service: `test_goal_service.py` без connection mock'а
- Переиспользование в Telegram: `from app.domain.goal_service import complete_goal`
- Каждый файл отвечает за одно (Single Responsibility)

**Затраты:** 2-3 часа рефакторинга

---

#### 2.2 Отсутствие Repository pattern (DB abstraction)
**Проблема:**
```python
# SQL прямо в handler'ах
connection.execute("SELECT * FROM goals WHERE id = ? AND user_id = ?")
connection.execute("UPDATE goals SET status = ...")
```
- Если когда-то нужна PostgreSQL, менять везде
- Нет единого места для валидации БД операций
- Сложно мокировать в тестах

**Рекомендуемый interface:**
```python
class GoalRepository:
    def create(self, user_id: int, data: GoalCreateIn) -> Goal:
        ...
    
    def get(self, user_id: int, goal_id: int) -> Goal:
        ...
    
    def update(self, user_id: int, goal_id: int, data: GoalUpdateIn) -> Goal:
        ...
    
    def list_by_date(self, user_id: int, target_date: str) -> List[Goal]:
        ...
    
    def complete(self, user_id: int, goal_id: int) -> Goal:
        ...
```

**Затраты:** 1 час

---

### TIER 3: ТЕСТИРОВАНИЕ (влияет на confidence)

#### 3.1 Нет unit-тестов
**Проблема:**
- 483 строк кода без покрытия
- Сложно менять код, боимся сломать
- Нет CI/CD pipeline

**Что нужно тестировать:**
```
tests/unit/test_goal_service.py:
- create_goal: validation, default date, source
- complete_goal: state transition, can't complete canceled
- snooze_goal: snooze_until = now + minutes
- move_to_tomorrow: date += 1
- apply_snooze_expired: snoozed -> active when expired
- batch_create: atomicity, all-or-nothing

tests/integration/test_goals_api.py:
- POST /api/goals (201, body check)
- GET /api/goals?date=... (sorting, snooze_expired applied)
- POST /api/goals/{id}/complete (409 if canceled)
- Error handling (VALIDATION_ERROR, CONFLICT_STATE, etc.)
```

**Затраты:** 2-3 часа

---

### TIER 4: OBSERVABILITY

#### 4.1 Логирование отсутствует
**Проблема:**
```python
def _apply_snooze_expired(...):
    # ... тихо работает, нет логов
    connection.execute("UPDATE goals SET status = 'active'...")
```

**Где нужны логи:**
```python
logger.info("Goal created", extra={"goal_id": 1, "user_id": 1, "source": "telegram"})
logger.warning("Goal state conflict", extra={"goal_id": 2, "current_status": "canceled", "action": "snooze"})
logger.debug("SNOOZE_EXPIRED applied", extra={"goal_id": 3, "snooze_until": "2026-02-24T18:00:00+01:00"})
```

**Затраты:** 30 мин

---

### TIER 5: DATABASE

#### 5.1 Нет миграций
**Проблема:**
```python
def init_db(db_path: Path):
    connection.executescript(DDL)  # Пересоздаёт с нуля!
```
- Если схема поменяется, все данные потеряются
- Нельзя откатить изменение
- Production nightmare

**Решение:** Alembic или собственный migration runner

**Затраты:** 1-2 часа

---

#### 5.2 Отсутствие нужных индексов
**Текущие индексы:**
```sql
CREATE INDEX idx_goals_user_target_date ON goals(user_id, target_date);
CREATE INDEX idx_goals_user_target_date_status ON goals(user_id, target_date, status);
CREATE INDEX idx_goals_status ON goals(status);
CREATE INDEX idx_goals_snooze_until ON goals(snooze_until);
```

**Отсутствуют:**
```sql
CREATE INDEX idx_goals_created_from ON goals(created_from);  -- telegram vs mobile analytics
CREATE INDEX idx_goals_updated_at ON goals(updated_at);       -- для sync по времени
```

**Затраты:** 5 мин

---

## РЕКОМЕНДАЦИИ

### ДО ЭТАПА 3 (Reminder Policy API)

**КРИТИЧЕСКИЕ (do now):**
1. ✅ Исправить batch transactions
2. ✅ Исправить race condition в SNOOZE_EXPIRED
3. ✅ Добавить валидацию time windows + интегрировать в PUT /api/reminder-policy

**ВАЖНЫЕ (do before production):**
4. Разделить goals.py на модули (2-3 часа)
5. Добавить Repository pattern (1 час)

### ПАРАЛЛЕЛЬНО С ЭТАПОМ 3

6. Добавить unit-тесты (2-3 часа)
7. Добавить логирование (30 мин)

### ПОСЛЕ ЭТАПА 4 (Telegram)

8. Добавить миграции (1 час)
9. Оптимизировать индексы (15 мин)

---

## ИМПАКТ-АНАЛИЗ

### Если НЕ исправить критические проблемы
- **Risk:** Data loss/corruption в batch operations
- **Risk:** Race conditions при concurrent requests
- **Risk:** Notification policy нарушает spec

### Если НЕ рефакторить архитектуру
- **Risk:** Telegram bot (этап 4) будет дублировать код
- **Risk:** Сложно добавлять новые фичи
- **Risk:** Тесты будут только integration (медленные)

### Если НЕ добавить тесты
- **Risk:** Регрессии при рефакторинге
- **Risk:** Сложно убедиться в корректности spec compliance

---

## ИТОГОВЫЙ ПЛАН

### Фаза 1 (ДО этапа 3): 4-5 часов
1. ✅ Batch transaction handling (10 мин) — DONE
2. ✅ Race condition fix (5 мин) — DONE
3. ✅ Time windows validation (15 мин) — DONE
4. ⏭️ Интегрировать валидацию в PUT /api/reminder-policy (этап 3)

### Фаза 2 (ПАРАЛЛЕЛЬНО с этапом 3): 3-4 часа
5. Разделить goals.py на модули (2-3 часа)
6. Добавить Repository pattern (1 час)
7. Добавить unit-тесты (2-3 часа)

### Фаза 3 (ПОСЛЕ этапа 4): 1-2 часа
8. Добавить логирование (30 мин)
9. Добавить миграции БД (1 час)

**ИТОГО:** ~10 часов рефакторинга для production-ready MVP

---

## ФАЙЛЫ ДОКУМЕНТАЦИИ

- `IMPROVEMENTS.md` — детальные рекомендации по каждой проблеме
- `IMPROVEMENTS_SUMMARY.md` — приоритезированный список
- `QUICK_FIXES_APPLIED.md` — что уже исправлено

