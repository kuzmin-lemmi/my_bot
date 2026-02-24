# NOTIFICATION SPEC — единые правила напоминаний (MVP v1)

## Цель
Повторно и настойчиво напоминать о целях дня, пока пользователь не выполнит действие.

## Это важно
Это НЕ непрерывный звук.
Это повторные уведомления по интервалу (реалистично для Android).

## Базовые настройки (по умолчанию)
- active_window_start = 09:00
- active_window_end = 21:00
- quiet_period_enabled = true
- quiet_period_start = 14:00
- quiet_period_end = 17:00
- interval_minutes = 30 (или пользовательское)
- default_snooze_options = [10, 30, 60]
- sound_enabled = true
- persistence_mode = soft
- escalation_enabled = true
- global_pause_until = null

## Режимы настойчивости
- soft
- normal
- hard

## Когда напоминать
Только если:
- status = active
- target_date = today
- now в active window
- now не в quiet period
- global pause не активна
- цель не snoozed/completed/canceled

## Чередование целей (rotation)
Если активных целей несколько:
- на каждом цикле выбирается следующая активная цель
- не напоминать одну и ту же подряд, если есть другие

## Эскалация (простая v1)
- reminder_ignore_count растёт при игноре
- effective interval может уменьшаться по шагу
- нижний предел интервала должен быть ограничен (например 5 минут)

## Действия и эффект
### Отложить
- status -> snoozed
- snooze_until = now + X минут

### Выполнено
- status -> completed
- отменить будущие уведомления по цели

### Завтра
- target_date += 1 day
- status -> active
- snooze_until = null
- отменить напоминания на сегодня

### Отменить
- status -> canceled
- напоминания прекращаются

## Глобальная пауза
- на X минут
- статусы задач не меняются
- после паузы уведомления возобновляются

## Автоперенос в конце дня
- active/snoozed -> на завтра
- фиксируется событие auto_moved_to_tomorrow

## Обязанность Mobile App
Пересобрать локальные уведомления после:
- запуска
- sync
- изменения целей
- действий по цели
- изменения policy
- выхода из global pause

## Edge cases (фиксировано для v1)
- Смена timezone устройства: выполнить полный sync и полную пересборку локального расписания
- Перезагрузка устройства: восстановить уведомления из локального состояния и после этого сделать sync
- Расхождение локального расписания и backend-данных: приоритет у backend (`updated_at` у goal/policy)
- Если цель была `snoozed`, но `snooze_until` уже в прошлом: считать целью `active` после sync
