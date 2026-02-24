from __future__ import annotations

import json
import sqlite3
from typing import Any

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.auth import require_auth
from app.config import get_settings
from app.db import get_connection, now_iso
from app.errors import APIError

router = APIRouter(prefix="/api/reminder-policy", tags=["reminder-policy"], dependencies=[Depends(require_auth)])


class ReminderPolicyUpdateIn(BaseModel):
    active_window_start: str | None = None
    active_window_end: str | None = None
    quiet_period_enabled: bool | None = None
    quiet_period_start: str | None = None
    quiet_period_end: str | None = None
    interval_minutes: int | None = Field(None, gt=0, le=1440)
    default_snooze_options: list[int] | None = None
    sound_enabled: bool | None = None
    persistence_mode: str | None = None
    escalation_enabled: bool | None = None
    escalation_step_minutes: int | None = Field(None, gt=0)
    ask_about_auto_moved_morning: bool | None = None


class GlobalPauseIn(BaseModel):
    minutes: int = Field(gt=0, le=1440)


def _db() -> sqlite3.Connection:
    return get_connection(get_settings().db_path)


def _single_user_id(connection: sqlite3.Connection) -> int:
    row = connection.execute("SELECT id FROM users ORDER BY id LIMIT 1").fetchone()
    if row is None:
        raise APIError("INTERNAL_ERROR", "Default user not initialized", 500)
    return int(row["id"])


def _validate_time_windows(
    active_start: str,
    active_end: str,
    quiet_enabled: bool,
    quiet_start: str | None,
    quiet_end: str | None,
) -> None:
    from datetime import time

    try:
        start_t = time.fromisoformat(active_start)
        end_t = time.fromisoformat(active_end)
    except ValueError as exc:
        raise APIError("VALIDATION_ERROR", "active_window times must be HH:MM", 400) from exc

    if start_t >= end_t:
        raise APIError(
            "BAD_TIME_WINDOW",
            "active_window_start must be before active_window_end",
            400,
        )

    if quiet_enabled:
        if not quiet_start or not quiet_end:
            raise APIError(
                "BAD_TIME_WINDOW",
                "quiet_period_start and quiet_period_end required when quiet_period_enabled=true",
                400,
            )
        try:
            qstart_t = time.fromisoformat(quiet_start)
            qend_t = time.fromisoformat(quiet_end)
        except ValueError as exc:
            raise APIError("VALIDATION_ERROR", "quiet_period times must be HH:MM", 400) from exc

        if qstart_t >= qend_t:
            raise APIError(
                "BAD_TIME_WINDOW",
                "quiet_period_start must be before quiet_period_end",
                400,
            )

        if not (start_t <= qstart_t and qend_t <= end_t):
            raise APIError(
                "BAD_TIME_WINDOW",
                "quiet_period must be within active_window",
                400,
            )


def _validate_snooze_options(options: list[int]) -> None:
    if not options:
        raise APIError("VALIDATION_ERROR", "snooze_options must not be empty", 400)
    if len(options) > 10:
        raise APIError("VALIDATION_ERROR", "snooze_options must have at most 10 items", 400)
    for opt in options:
        if opt <= 0 or opt > 1440:
            raise APIError(
                "BAD_SNOOZE_OPTION",
                f"snooze_option must be between 1 and 1440 minutes, got {opt}",
                400,
            )


def _validate_persistence_mode(mode: str) -> None:
    if mode not in ("soft", "normal", "hard"):
        raise APIError("VALIDATION_ERROR", f"persistence_mode must be soft|normal|hard, got {mode}", 400)


def _policy_to_dto(row: sqlite3.Row) -> dict[str, Any]:
    snooze_options = json.loads(row["default_snooze_options"]) if row["default_snooze_options"] else []
    return {
        "active_window_start": row["active_window_start"],
        "active_window_end": row["active_window_end"],
        "quiet_period_enabled": bool(row["quiet_period_enabled"]),
        "quiet_period_start": row["quiet_period_start"],
        "quiet_period_end": row["quiet_period_end"],
        "interval_minutes": row["interval_minutes"],
        "default_snooze_options": snooze_options,
        "sound_enabled": bool(row["sound_enabled"]),
        "persistence_mode": row["persistence_mode"],
        "escalation_enabled": bool(row["escalation_enabled"]),
        "escalation_step_minutes": row["escalation_step_minutes"],
        "global_pause_until": row["global_pause_until"],
        "ask_about_auto_moved_morning": bool(row["ask_about_auto_moved_morning"]),
        "updated_at": row["updated_at"],
    }


@router.get("")
def get_reminder_policy() -> dict[str, object]:
    with _db() as connection:
        user_id = _single_user_id(connection)
        row = connection.execute("SELECT * FROM reminder_policies WHERE user_id = ?", (user_id,)).fetchone()
        if row is None:
            raise APIError("INTERNAL_ERROR", "Policy not initialized for user", 500)
        return {"ok": True, "data": {"policy": _policy_to_dto(row)}}


@router.put("")
def update_reminder_policy(payload: ReminderPolicyUpdateIn) -> dict[str, object]:
    if payload.model_dump(exclude_none=True) == {}:
        raise APIError("VALIDATION_ERROR", "No fields provided for update", 400)

    with _db() as connection:
        user_id = _single_user_id(connection)
        current = connection.execute("SELECT * FROM reminder_policies WHERE user_id = ?", (user_id,)).fetchone()
        if current is None:
            raise APIError("INTERNAL_ERROR", "Policy not initialized for user", 500)

        active_start = payload.active_window_start if payload.active_window_start is not None else current["active_window_start"]
        active_end = payload.active_window_end if payload.active_window_end is not None else current["active_window_end"]
        quiet_enabled = payload.quiet_period_enabled if payload.quiet_period_enabled is not None else bool(current["quiet_period_enabled"])
        quiet_start = payload.quiet_period_start if payload.quiet_period_start is not None else current["quiet_period_start"]
        quiet_end = payload.quiet_period_end if payload.quiet_period_end is not None else current["quiet_period_end"]

        _validate_time_windows(active_start, active_end, quiet_enabled, quiet_start, quiet_end)

        interval = payload.interval_minutes if payload.interval_minutes is not None else current["interval_minutes"]

        if payload.default_snooze_options is not None:
            _validate_snooze_options(payload.default_snooze_options)
            snooze_options = json.dumps(payload.default_snooze_options)
        else:
            snooze_options = current["default_snooze_options"]

        sound_enabled = payload.sound_enabled if payload.sound_enabled is not None else bool(current["sound_enabled"])

        if payload.persistence_mode is not None:
            _validate_persistence_mode(payload.persistence_mode)
            persistence_mode = payload.persistence_mode
        else:
            persistence_mode = current["persistence_mode"]

        escalation_enabled = payload.escalation_enabled if payload.escalation_enabled is not None else bool(current["escalation_enabled"])
        escalation_step = payload.escalation_step_minutes if payload.escalation_step_minutes is not None else current["escalation_step_minutes"]
        ask_about_auto = payload.ask_about_auto_moved_morning if payload.ask_about_auto_moved_morning is not None else bool(current["ask_about_auto_moved_morning"])

        timestamp = now_iso()
        connection.execute(
            """
            UPDATE reminder_policies
            SET active_window_start = ?,
                active_window_end = ?,
                quiet_period_enabled = ?,
                quiet_period_start = ?,
                quiet_period_end = ?,
                interval_minutes = ?,
                default_snooze_options = ?,
                sound_enabled = ?,
                persistence_mode = ?,
                escalation_enabled = ?,
                escalation_step_minutes = ?,
                ask_about_auto_moved_morning = ?,
                updated_at = ?
            WHERE user_id = ?
            """,
            (
                active_start,
                active_end,
                int(quiet_enabled),
                quiet_start,
                quiet_end,
                interval,
                snooze_options,
                int(sound_enabled),
                persistence_mode,
                int(escalation_enabled),
                escalation_step,
                int(ask_about_auto),
                timestamp,
                user_id,
            ),
        )
        connection.commit()

        updated = connection.execute("SELECT * FROM reminder_policies WHERE user_id = ?", (user_id,)).fetchone()
        if updated is None:
            raise APIError("INTERNAL_ERROR", "Policy update failed", 500)

        return {"ok": True, "data": {"policy": _policy_to_dto(updated)}}


@router.post("/global-pause")
def set_global_pause(payload: GlobalPauseIn) -> dict[str, object]:
    from datetime import datetime, timedelta

    pause_until = (datetime.now() + timedelta(minutes=payload.minutes)).isoformat(timespec="seconds")

    with _db() as connection:
        user_id = _single_user_id(connection)
        timestamp = now_iso()
        connection.execute(
            """
            UPDATE reminder_policies
            SET global_pause_until = ?, updated_at = ?
            WHERE user_id = ?
            """,
            (pause_until, timestamp, user_id),
        )
        connection.commit()

        updated = connection.execute("SELECT * FROM reminder_policies WHERE user_id = ?", (user_id,)).fetchone()
        if updated is None:
            raise APIError("INTERNAL_ERROR", "Global pause update failed", 500)

        return {"ok": True, "data": {"policy": _policy_to_dto(updated)}}


@router.post("/global-pause/clear")
def clear_global_pause() -> dict[str, object]:
    with _db() as connection:
        user_id = _single_user_id(connection)
        timestamp = now_iso()
        connection.execute(
            """
            UPDATE reminder_policies
            SET global_pause_until = NULL, updated_at = ?
            WHERE user_id = ?
            """,
            (timestamp, user_id),
        )
        connection.commit()

        updated = connection.execute("SELECT * FROM reminder_policies WHERE user_id = ?", (user_id,)).fetchone()
        if updated is None:
            raise APIError("INTERNAL_ERROR", "Clear global pause failed", 500)

        return {"ok": True, "data": {"policy": _policy_to_dto(updated)}}
