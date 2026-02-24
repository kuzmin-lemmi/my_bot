# DATA SCHEMA — SQLite schema draft (MVP v1)

## Статус схемы
- Версия: v1 (утверждена для старта реализации)
- Дата фиксации: 2026-02-24
- Правило: изменения таблиц/индексов сначала фиксируются в этом файле

## users
- id
- telegram_id (unique)
- display_name
- timezone (default Europe/Paris)
- created_at
- updated_at

## goals
- id
- user_id
- title
- note
- target_date (YYYY-MM-DD)
- target_time (HH:MM nullable)
- priority
- status (active|snoozed|completed|canceled)
- snooze_until (ISO datetime nullable)
- created_from (telegram|mobile)
- last_reminded_at
- reminder_ignore_count (int default 0)
- completed_at
- canceled_at
- created_at
- updated_at

Индексы:
- (user_id, target_date)
- (user_id, target_date, status)
- (status)
- (snooze_until)

## reminder_policies
- user_id (PK)
- active_window_start
- active_window_end
- quiet_period_enabled
- quiet_period_start
- quiet_period_end
- interval_minutes
- default_snooze_options (JSON string)
- sound_enabled
- persistence_mode (soft|normal|hard)
- escalation_enabled
- escalation_step_minutes
- global_pause_until
- ask_about_auto_moved_morning
- updated_at

## goal_action_events
- id
- goal_id
- action_type
- action_payload (JSON string)
- source (telegram|mobile|backend_auto)
- created_at

Индексы:
- (goal_id)
- (created_at)
- (action_type)

## Валидация (backend)
- title не пустой после trim
- active_window_start < active_window_end (v1)
- quiet period валиден и внутри active window (v1)
- interval_minutes > 0
- snooze options = список положительных чисел
