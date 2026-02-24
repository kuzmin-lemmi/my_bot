# DOMAIN MODEL — доменные сущности MVP

## Термины
- Goal = важная цель/дело
- Target Date = дата, на которую назначена цель
- Reminder Policy = правила напоминаний
- Action Event = запись в журнале действий по цели

## Entity: User (single-user, но модель оставляем расширяемой)
- id (uuid/int)
- telegram_id (unique)
- display_name (optional)
- timezone (string, например Europe/Paris)
- created_at
- updated_at

## Entity: Goal
- id
- user_id
- title (string, required)
- note (text, optional)
- target_date (date, required)
- target_time (time, optional)
- priority (string/int, optional; v1 логика не зависит)
- status (enum)
- created_from (telegram | mobile)
- created_at
- updated_at
- completed_at (nullable)
- canceled_at (nullable)
- snooze_until (nullable datetime)
- last_reminded_at (nullable datetime)
- reminder_ignore_count (int, default 0)  // для простой эскалации

## Entity: ReminderPolicy
- user_id
- active_window_start (time)         // default 09:00
- active_window_end (time)           // default 21:00
- quiet_period_enabled (bool)
- quiet_period_start (time nullable) // example 14:00
- quiet_period_end (time nullable)   // example 17:00
- interval_minutes (int)             // пользовательский
- default_snooze_options (json/text) // например [10,30,60]
- sound_enabled (bool)
- persistence_mode (soft | normal | hard)
- escalation_enabled (bool)
- escalation_step_minutes (int nullable)
- global_pause_until (nullable datetime)
- ask_about_auto_moved_morning (bool)
- updated_at

## Entity: GoalActionEvent (журнал)
- id
- goal_id
- action_type (enum)
- action_payload (json/text)
- source (telegram | mobile | backend_auto)
- created_at

Примеры action_type:
- created
- updated
- completed
- snoozed
- moved_to_tomorrow
- canceled
- auto_moved_to_tomorrow
- reminder_sent
- reminder_ignored
- restored

## Goal Status (v1)
- active
- snoozed
- completed
- canceled

## Важное решение (фиксировано)
"Перенести на завтра" = та же задача, обновляется target_date (+1 день), событие пишется в журнал.
Новая задача НЕ создаётся.
