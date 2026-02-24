# УЛУЧШЕНИЯ В РЕАЛИЗОВАННЫХ ЭТАПАХ

Анализ текущего состояния (этапы 0-2) и рекомендации по оптимизации.

## 1. АРХИТЕКТУРНЫЕ ПРОБЛЕМЫ

### 1.1 Смешивание ответственности в goals.py (473 строки)
**Проблема:**
- Один файл содержит: DTO, валидацию, логику БД, бизнес-логику, route handlers
- Сложно тестировать
- Сложно переиспользовать логику

**Решение:**
```
backend/app/
├── models/
│   ├── goal.py         # DTO + Pydantic-модели
│   ├── event.py        # Event DTO
│   └── __init__.py
├── domain/
│   ├── goal_service.py # Бизнес-логика целей (create, complete, snooze и т.д.)
│   ├── goal_repository.py # Доступ к БД
│   └── __init__.py
├── api/
│   ├── goals.py        # Только route handlers
│   ├── health.py
│   └── __init__.py
```

**Преимущества:**
- Бизнес-логика отделена от HTTP-слоя
- Легче написать unit-тесты
- Переиспользуется в Telegram-боте (этап 4)

---

### 1.2 Отсутствие зависимости от хранилища (repository/DAO pattern)
**Проблема:**
- SQL прямо в handlers'ах
- Сложно менять БД (если когда-то понадобится PostgreSQL)
- Нет единого места для валидации БД

**Решение:**
```python
# backend/app/domain/goal_repository.py
class GoalRepository:
    def __init__(self, db_path: Path):
        self.db_path = db_path
    
    def create_goal(self, user_id: int, data: GoalCreateIn) -> Goal:
        # SQL логика
        
    def get_goal(self, user_id: int, goal_id: int) -> Goal:
        # SQL + SNOOZE_EXPIRED проверка
```

---

### 1.3 `_apply_snooze_expired` во время каждого fetch'а (O(N) в цикле)
**Проблема:**
- В `list_goals` может быть 50 целей × commit каждый раз
- Плохо для performance

**Решение:**
- Отдельный batch-метод `apply_expired_snoozes(goals: List[Goal]) -> List[Goal]`
- Один commit в конце

---

## 2. ВАЛИДАЦИЯ И ОБРАБОТКА ОШИБОК

### 2.1 Нет валидации времени окна активности (quiet period)
**Проблема:**
- В spec: "quiet period должен быть внутри active window"
- Нет проверки при создании/обновлении reminder policy

**Решение:**
```python
def validate_time_windows(policy: ReminderPolicy) -> None:
    if policy.active_window_start >= policy.active_window_end:
        raise APIError("BAD_TIME_WINDOW", "...", 400)
    
    if policy.quiet_period_enabled:
        if not policy.quiet_period_start or not policy.quiet_period_end:
            raise APIError("BAD_TIME_WINDOW", "...", 400)
        if policy.quiet_period_start >= policy.quiet_period_end:
            raise APIError("BAD_TIME_WINDOW", "...", 400)
        if not (policy.active_window_start <= policy.quiet_period_start
                and policy.quiet_period_end <= policy.active_window_end):
            raise APIError("BAD_TIME_WINDOW", "...", 400)
```

---

### 2.2 Нет валидации snooze options (должны быть положительные числа)
**Проблема:**
- Можно передать `[-1, 0, 999999]`
- Нет проверки нижней/верхней границ

**Решение:**
```python
def validate_snooze_options(options: list[int]) -> None:
    if not options:
        raise APIError("VALIDATION_ERROR", "snooze_options must not be empty", 400)
    for opt in options:
        if opt <= 0 or opt > 1440:  # макс 24 часа
            raise APIError("BAD_SNOOZE_OPTION", f"Invalid snooze option: {opt}", 400)
```

---

## 3. ОБРАБОТКА CONCURRENCY И STATE

### 3.1 Race condition в `_apply_snooze_expired`
**Проблема:**
```python
if datetime.now().astimezone() < snooze_until:
    return row  # Старое состояние
# К этому моменту может быть другой процесс
connection.execute("UPDATE goals SET status = 'active'...")
```
- Если два процесса одновременно, можно потерять данные

**Решение:**
```python
# Сначала обновить в БД, потом прочитать
UPDATE goals 
SET status = CASE 
    WHEN status = 'snoozed' AND datetime(snooze_until) <= datetime('now', 'localtime')
    THEN 'active'
    ELSE status
END
WHERE id = ?
```

---

### 3.2 Отсутствие транзакций при batch операциях
**Проблема:**
```python
@router.post("/batch")
def create_goals_batch(payload: GoalBatchIn):
    for item in payload.items:
        _create_goal(connection, user_id, item)  # commit после каждого!
```
- Если 10 целей, а 8-я упадёт — уже создано 7

**Решение:**
```python
try:
    for item in payload.items:
        _create_goal(connection, user_id, item)
    connection.commit()
except Exception:
    connection.rollback()
    raise
```

---

## 4. ТЕСТИРУЕМОСТЬ

### 4.1 Нет модульных тестов
**Проблема:**
- 473 строки кода без unit-тестов
- Нет CI/CD

**Решение:**
```
backend/tests/
├── unit/
│   ├── test_goal_service.py
│   ├── test_goal_repository.py
│   └── test_validators.py
├── integration/
│   └── test_goals_api.py
└── conftest.py
```

---

### 4.2 Нет типов для SQL Row
**Проблема:**
```python
row = connection.execute(...).fetchone()
row["id"]  # Type checker не знает, что это существует
```

**Решение:**
```python
from typing import TypedDict

class GoalRow(TypedDict):
    id: int
    title: str
    status: str
    ...

def _fetch_goal(...) -> GoalRow:
    ...
```

---

## 5. ЛОГИРОВАНИЕ И OBSERVABILITY

### 5.1 Почти нет логирования в бизнес-логике
**Проблема:**
- `_create_event`, `_apply_snooze_expired` молча работают
- Сложно отладить production issues

**Решение:**
```python
logger = logging.getLogger(__name__)

def _apply_snooze_expired(connection, row):
    if row["status"] != "snoozed" or not row["snooze_until"]:
        return row
    
    snooze_until = _parse_dt(row["snooze_until"])
    if datetime.now().astimezone() < snooze_until:
        return row
    
    logger.info("Applying SNOOZE_EXPIRED for goal %d", row["id"])
    # ...
    logger.debug("Goal %d transitioned to active", row["id"])
```

---

### 5.2 Нет структурированного логирования
**Проблема:**
- Логи нельзя спарсить machine-readable way
- Сложно анализировать ошибки

**Решение:**
```python
logger.info(
    "goal_action",
    extra={
        "goal_id": goal_id,
        "action": "completed",
        "user_id": user_id,
        "duration_ms": elapsed,
    }
)
```

---

## 6. API ДИЗАЙН

### 6.1 `ConfirmIn` параметр не используется полностью
**Проблема:**
```python
@router.post("/{goal_id}/complete")
def complete_goal(goal_id: int, _: ConfirmIn | None = None) -> dict[str, object]:
    # Параметр игнорируется, просто используется как сигнал что тело есть
```

**Решение:**
- Либо использовать параметр: если `confirmed=False`, вернуть `422`
- Либо удалить и сделать POST без body, если нет причин требовать confirmation логики

---

### 6.2 Нет pagination в `/api/goals` для больших дат
**Проблема:**
- Если на дату 500 целей, вернётся всё
- Сложный JSON

**Решение:**
```python
@router.get("")
def list_goals(
    date_value: str = Query(..., alias="date"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
) -> dict[str, object]:
    ...
    rows = connection.execute(...).fetchall()[offset : offset + limit]
    return {
        "ok": True,
        "data": {
            "date": date_value,
            "items": [_goal_to_dto(row) for row in rows],
            "total": len(all_rows),
            "limit": limit,
            "offset": offset,
        },
    }
```

---

## 7. DATABASE

### 7.1 Нет миграций (alembic/flyway)
**Проблема:**
- `init_db` пересоздаёт БД с нуля
- Если схема изменится, старые данные потеряются
- Невозможно откатить изменение

**Решение:**
```
backend/migrations/
├── versions/
│   ├── 001_initial_schema.sql
│   ├── 002_add_column_x.sql
│   └── ...
└── apply.py
```

---

### 7.2 Нет индекса на `created_from` в goals (фильтрация telegram vs mobile)
**Проблема:**
- Если будет анализ "сколько целей создано через Telegram", медленно

**Решение:**
```sql
CREATE INDEX idx_goals_created_from ON goals(created_from);
```

---

## 8. КОНФИГУРАЦИЯ

### 8.1 Токены в env без безопасности
**Проблема:**
```python
mvp_token=os.getenv("MVP_TOKEN", "")
```
- Если `MVP_TOKEN` не установлен, auth отключается (`if not settings.mvp_token: return`)
- Может быть случайным

**Решение:**
```python
mvp_token=os.getenv("MVP_TOKEN")
if not mvp_token:
    raise ValueError("MVP_TOKEN must be set")
```

---

### 8.2 Нет разных конфигов для dev/prod
**Проблема:**
```python
app_env=os.getenv("APP_ENV", "dev")
# ... но не используется
```

**Решение:**
```python
@dataclass(frozen=True)
class Settings:
    app_env: str
    log_level: str
    db_path: Path
    cors_origins: list[str]
    
    @classmethod
    def from_env(cls) -> Settings:
        env = os.getenv("APP_ENV", "dev")
        if env == "prod":
            return cls(
                app_env="prod",
                log_level="WARNING",
                db_path=Path("/var/lib/mvp/db.sqlite"),
                cors_origins=["https://example.com"],
            )
        else:
            return cls(
                app_env="dev",
                log_level="DEBUG",
                db_path=Path("data/mvp_control.db"),
                cors_origins=["*"],
            )
```

---

## ПРИОРИТЕТ УЛУЧШЕНИЙ (по важности для MVP)

1. **ВЫСОКИЙ (do now)**
   - Разделить goals.py на models + domain + api (architecture)
   - Добавить GoalRepository (абстракция БД)
   - Добавить batch transaction handling (data integrity)
   - Добавить валидацию time windows (spec compliance)

2. **СРЕДНИЙ (do soon)**
   - Добавить модульные тесты
   - Добавить структурированное логирование
   - Добавить миграции БД
   - Убрать race condition в SNOOZE_EXPIRED

3. **НИЗКИЙ (polish later)**
   - Pagination в list endpoints
   - Дополнительные индексы БД
   - Dev/prod configs
   - TypedDict для Row'ов

---

## РЕКОМЕНДУЕМЫЙ ПОРЯДОК РЕФАКТОРИНГА

Не блокирует этап 3-4, но делать параллельно:

1. Создать `backend/app/domain/goal_service.py` + `goal_repository.py`
2. Переместить логику из goals.py в service
3. Оставить в goals.py только route handlers (10-20 строк max)
4. Добавить базовые unit-тесты для service
5. Обновить todo-лист

**Ожидаемый результат:**
- goals.py сократится с 473 до ~100 строк
- Появится переиспользуемая логика для Telegram-бота
- Легче будет добавлять новые функции
