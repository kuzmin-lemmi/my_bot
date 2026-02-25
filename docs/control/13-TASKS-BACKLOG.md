# TASKS BACKLOG — стартовый бэклог MVP с разделением по ролям

## PHASE 0 — фиксация
### LOGIC
- [x] Утвердить API CONTRACT v1
- [x] Утвердить STATE MACHINE v1
- [x] Утвердить SQLite schema v1

### UI
- [x] Утвердить UI flow (Сегодня / Календарь / День / Добавить / Настройки)
- [x] Утвердить карточку цели и действия

## PHASE 1 — Backend core (Claude)
### LOGIC
- [x] Поднять backend (Python)
- [x] SQLite + миграции/init schema
- [x] Таблицы users/goals/reminder_policies/events
- [x] POST /api/goals
- [x] POST /api/goals/batch
- [x] GET /api/goals?date=
- [x] PUT /api/goals/{id}
- [x] /complete /snooze /move-to-tomorrow /cancel
- [x] GET/PUT reminder-policy
- [x] global pause endpoints
- [x] GET /api/goals/calendar?month=
- [x] GET /api/events?date=
- [x] валидация переходов состояний
- [x] seed default reminder policy

## PHASE 2 — Telegram input (Claude)
### LOGIC
- [x] aiogram bot
- [x] /start, /help
- [x] простой текст -> цель на сегодня
- [x] несколько строк -> batch
- [ ] (опц.) /add YYYY-MM-DD ...
- [x] запись в backend сервис

## PHASE 3 — Mobile UI core (Claude)
### UI
- [x] Scaffold Flutter app (mobile/ directory)
- [x] Навигация (Material routes)
- [x] Экран "Сегодня" (TodayScreen)
- [x] Карточка цели + 4 кнопки (GoalCard + actions)
- [x] Подтверждение для Выполнено/Отменить (Dialogs)
- [x] Календарь (month) (TableCalendar integration)
- [x] Экран "День" (Интегрировано в TodayScreen через выбор даты)
- [x] Добавить/Редактировать цель (GoalEditScreen)
- [x] Настройки напоминаний (SettingsScreen)
- [x] Журнал (JournalScreen)

## PHASE 4 — Integration
### UI
- [x] API client (ApiService)
- [x] Fetch goals by date (GoalProvider)
- [x] Actions complete/snooze/move/cancel (GoalProvider actions)
- [x] Обновление состояния после действий (notifyListeners)
- [x] Ошибки сети + retry (Базовая обработка в ApiService/Provider)
- [x] Pull-to-refresh (RefreshIndicator на главном экране)


### LOGIC
- [ ] Network config/CORS
- [ ] Стабилизировать errors
- [ ] Логи отладки

## PHASE 5 — Notifications
### LOGIC
- [x] Финализировать правила уведомлений в коде
- [x] Данные/policy для sync

### UI
- [x] Локальные уведомления Android (flutter_local_notifications)
- [x] Пересоздание расписания (после fetch/actions)
- [x] Rotation active goals (базовая реализация в NotificationService)
- [x] Global pause UI (TodayScreen banner)
- [x] Quiet period UI (учитывается при расчёте следующего уведомления)
- [x] Эскалация (логика в NotificationService, расчёт интервала)
- [ ] Тестирование уведомлений на реальном устройстве

## PHASE 6 — Daily rollover / journal / polish
### LOGIC
- [x] Автоперенос на завтра (POST /api/goals/rollover)
- [x] auto_moved_to_tomorrow event (source=backend_auto)
- [x] morning summary source (moved_count + goals list в response)

### UI
- [ ] Утренний экран/диалог по автопереносам
- [x] Журнал событий (JournalScreen)
- [ ] UX-проверка на реальных 3–5 целях в день

## PHASE 7 — Final Polish (Stage 8)
### LOGIC & UI
- [x] Android Manifest (permissions, receivers)
- [x] build.gradle конфигурация
- [x] .gitignore для mobile/
- [x] Документация деплоя (DEPLOYMENT.md)
- [ ] README.md для всего проекта
- [ ] Финальное тестирование на реальном устройстве
