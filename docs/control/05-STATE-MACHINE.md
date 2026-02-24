# STATE MACHINE — жизненный цикл цели (MVP v1)

## Состояния Goal
- active
- snoozed
- completed
- canceled

## События / команды
- CREATE_GOAL
- UPDATE_GOAL
- COMPLETE
- SNOOZE(minutes)
- SNOOZE_EXPIRED
- MOVE_TO_TOMORROW
- CANCEL
- AUTO_MOVE_TO_TOMORROW
- RESTORE (опционально v1.1)

## Переходы
- none -> active (CREATE_GOAL)
- active|snoozed -> completed (COMPLETE)
- active -> snoozed (SNOOZE)
- snoozed -> active (SNOOZE_EXPIRED)
- active|snoozed -> active (MOVE_TO_TOMORROW / AUTO_MOVE_TO_TOMORROW, с переносом даты)
- active|snoozed -> canceled (CANCEL)

## Эффекты переходов
### SNOOZE
- snooze_until = now + X минут

### SNOOZE_EXPIRED
- status = active
- snooze_until = null

### MOVE_TO_TOMORROW / AUTO_MOVE_TO_TOMORROW
- target_date = target_date + 1 day
- snooze_until = null
- reminder_ignore_count = 0

## Запреты
- completed нельзя snooze
- completed нельзя move-to-tomorrow (в MVP)
- canceled не напоминается
- canceled не считается в активных

## Утренний вопрос про автоперенос
Если есть авто-перенесённые задачи:
- UI утром показывает список/подтверждение
- это НЕ отдельный статус задачи

## Правила напоминаний (кратко)
Напоминать только если:
- status == active
- target_date == today
- текущее время внутри active window
- не внутри quiet period
- нет global pause

## Исполнение SNOOZE_EXPIRED (фиксировано)
- Источник истины: backend
- Backend обязан применять переход `snoozed -> active`, когда `now >= snooze_until`
- Применение допускается лениво (при чтении/действии/sync) или фоновым джобом
- После применения перехода backend возвращает уже актуальный `status=active`
