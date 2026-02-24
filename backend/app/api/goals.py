from __future__ import annotations

import calendar
import json
import sqlite3
from datetime import date, datetime, time, timedelta
from typing import Any, Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field

from app.auth import require_auth
from app.config import get_settings
from app.db import get_connection, now_iso
from app.errors import APIError

SourceType = Literal["telegram", "mobile"]

router = APIRouter(prefix="/api/goals", tags=["goals"], dependencies=[Depends(require_auth)])


class GoalCreateIn(BaseModel):
    title: str = Field(min_length=1)
    note: str | None = None
    target_date: str | None = None
    target_time: str | None = None
    priority: str | None = None
    source: SourceType = "mobile"


class GoalBatchIn(BaseModel):
    items: list[GoalCreateIn]


class GoalUpdateIn(BaseModel):
    title: str | None = None
    note: str | None = None
    target_date: str | None = None
    target_time: str | None = None
    priority: str | None = None


class SnoozeIn(BaseModel):
    minutes: int = Field(gt=0)


class ConfirmIn(BaseModel):
    confirmed: bool = True


def _db() -> sqlite3.Connection:
    return get_connection(get_settings().db_path)


def _single_user_id(connection: sqlite3.Connection) -> int:
    row = connection.execute("SELECT id FROM users ORDER BY id LIMIT 1").fetchone()
    if row is None:
        raise APIError("INTERNAL_ERROR", "Default user not initialized", 500)
    return int(row["id"])


def _normalize_title(title: str) -> str:
    value = title.strip()
    if not value:
        raise APIError("VALIDATION_ERROR", "title must not be empty", 400)
    return value


def _normalize_date(value: str | None) -> str:
    if value is None:
        return date.today().isoformat()
    try:
        parsed = date.fromisoformat(value)
    except ValueError as exc:
        raise APIError("VALIDATION_ERROR", "target_date must be YYYY-MM-DD", 400) from exc
    return parsed.isoformat()


def _normalize_time(value: str | None) -> str | None:
    if value is None or value == "":
        return None
    try:
        parsed = time.fromisoformat(value)
    except ValueError as exc:
        raise APIError("VALIDATION_ERROR", "target_time must be HH:MM", 400) from exc
    return parsed.strftime("%H:%M")


def _goal_to_dto(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "title": row["title"],
        "note": row["note"],
        "target_date": row["target_date"],
        "target_time": row["target_time"],
        "priority": row["priority"],
        "status": row["status"],
        "snooze_until": row["snooze_until"],
        "created_from": row["created_from"],
        "last_reminded_at": row["last_reminded_at"],
        "reminder_ignore_count": row["reminder_ignore_count"],
        "completed_at": row["completed_at"],
        "canceled_at": row["canceled_at"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def _event_to_dto(row: sqlite3.Row) -> dict[str, Any]:
    payload = row["action_payload"]
    parsed_payload = json.loads(payload) if payload else {}
    return {
        "id": row["id"],
        "goal_id": row["goal_id"],
        "action_type": row["action_type"],
        "action_payload": parsed_payload,
        "source": row["source"],
        "created_at": row["created_at"],
    }


def _create_event(
    connection: sqlite3.Connection,
    goal_id: int,
    action_type: str,
    source: str,
    payload: dict[str, Any] | None = None,
) -> sqlite3.Row:
    timestamp = now_iso()
    cursor = connection.execute(
        """
        INSERT INTO goal_action_events (goal_id, action_type, action_payload, source, created_at)
        VALUES (?, ?, ?, ?, ?)
        """,
        (goal_id, action_type, json.dumps(payload or {}), source, timestamp),
    )
    event_id = int(cursor.lastrowid)
    return connection.execute(
        "SELECT * FROM goal_action_events WHERE id = ?", (event_id,)
    ).fetchone()


def _fetch_goal(connection: sqlite3.Connection, user_id: int, goal_id: int) -> sqlite3.Row:
    row = connection.execute(
        "SELECT * FROM goals WHERE id = ? AND user_id = ?",
        (goal_id, user_id),
    ).fetchone()
    if row is None:
        raise APIError("NOT_FOUND", "Goal not found", 404)
    return _apply_snooze_expired(connection, row)


def _parse_dt(value: str) -> datetime:
    try:
        dt = datetime.fromisoformat(value)
    except ValueError as exc:
        raise APIError("INTERNAL_ERROR", "Invalid datetime in DB", 500) from exc
    if dt.tzinfo is None:
        return dt.astimezone()
    return dt


def _apply_snooze_expired(connection: sqlite3.Connection, row: sqlite3.Row) -> sqlite3.Row:
    if row["status"] != "snoozed" or not row["snooze_until"]:
        return row

    snooze_until = _parse_dt(row["snooze_until"])
    if datetime.now().astimezone() < snooze_until:
        return row

    timestamp = now_iso()
    connection.execute(
        """
        UPDATE goals
        SET status = 'active', snooze_until = NULL, updated_at = ?
        WHERE id = ? AND status = 'snoozed'
        """,
        (timestamp, row["id"]),
    )
    refreshed = connection.execute("SELECT * FROM goals WHERE id = ?", (row["id"],)).fetchone()
    if refreshed is None:
        raise APIError("INTERNAL_ERROR", "Goal update failed", 500)
    return refreshed


def _assert_state(current: str, allowed: set[str], action: str) -> None:
    if current not in allowed:
        raise APIError(
            "CONFLICT_STATE",
            f"Cannot {action} when goal status is '{current}'",
            409,
        )


def _create_goal(connection: sqlite3.Connection, user_id: int, item: GoalCreateIn) -> sqlite3.Row:
    timestamp = now_iso()
    title = _normalize_title(item.title)
    target_date = _normalize_date(item.target_date)
    target_time = _normalize_time(item.target_time)

    cursor = connection.execute(
        """
        INSERT INTO goals (
            user_id,
            title,
            note,
            target_date,
            target_time,
            priority,
            status,
            snooze_until,
            created_from,
            last_reminded_at,
            reminder_ignore_count,
            completed_at,
            canceled_at,
            created_at,
            updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, 'active', NULL, ?, NULL, 0, NULL, NULL, ?, ?)
        """,
        (
            user_id,
            title,
            item.note,
            target_date,
            target_time,
            item.priority,
            item.source,
            timestamp,
            timestamp,
        ),
    )
    goal_id = int(cursor.lastrowid)
    _create_event(connection, goal_id, "created", item.source, {"target_date": target_date})
    row = connection.execute("SELECT * FROM goals WHERE id = ?", (goal_id,)).fetchone()
    if row is None:
        raise APIError("INTERNAL_ERROR", "Goal create failed", 500)
    return row


@router.post("")
def create_goal(payload: GoalCreateIn) -> dict[str, object]:
    with _db() as connection:
        user_id = _single_user_id(connection)
        goal = _create_goal(connection, user_id, payload)
        connection.commit()
        return {"ok": True, "data": {"goal": _goal_to_dto(goal)}}


@router.post("/batch")
def create_goals_batch(payload: GoalBatchIn) -> dict[str, object]:
    if not payload.items:
        raise APIError("VALIDATION_ERROR", "items must not be empty", 400)

    try:
        with _db() as connection:
            user_id = _single_user_id(connection)
            rows = [_create_goal(connection, user_id, item) for item in payload.items]
            connection.commit()
            return {
                "ok": True,
                "data": {
                    "created_count": len(rows),
                    "goals": [_goal_to_dto(row) for row in rows],
                },
            }
    except APIError:
        raise
    except Exception as exc:
        raise APIError("INTERNAL_ERROR", f"Batch operation failed: {str(exc)}", 500) from exc


@router.get("")
def list_goals(date_value: str = Query(..., alias="date")) -> dict[str, object]:
    target_date = _normalize_date(date_value)
    with _db() as connection:
        user_id = _single_user_id(connection)
        rows = connection.execute(
            """
            SELECT * FROM goals
            WHERE user_id = ? AND target_date = ?
            ORDER BY
                CASE status
                    WHEN 'active' THEN 1
                    WHEN 'snoozed' THEN 2
                    WHEN 'completed' THEN 3
                    WHEN 'canceled' THEN 4
                END,
                CASE WHEN target_time IS NULL THEN 1 ELSE 0 END,
                target_time,
                id
            """,
            (user_id, target_date),
        ).fetchall()
        normalized_rows = [_apply_snooze_expired(connection, row) for row in rows]
        connection.commit()
        return {
            "ok": True,
            "data": {
                "date": target_date,
                "items": [_goal_to_dto(row) for row in normalized_rows],
            },
        }


@router.get("/calendar")
def get_calendar(month: str = Query(...)) -> dict[str, object]:
    try:
        year, month_num = map(int, month.split("-"))
    except (ValueError, IndexError) as exc:
        raise APIError("VALIDATION_ERROR", "month must be YYYY-MM", 400) from exc

    if month_num < 1 or month_num > 12:
        raise APIError("VALIDATION_ERROR", "month must be 01-12", 400)

    with _db() as connection:
        user_id = _single_user_id(connection)
        month_cal = calendar.monthcalendar(year, month_num)
        days_data = []

        for week in month_cal:
            for day_num in week:
                if day_num == 0:
                    continue

                target_date = f"{year:04d}-{month_num:02d}-{day_num:02d}"
                rows = connection.execute(
                    """
                    SELECT status, COUNT(*) as cnt
                    FROM goals
                    WHERE user_id = ? AND target_date = ?
                    GROUP BY status
                    """,
                    (user_id, target_date),
                ).fetchall()

                counts = {"active": 0, "snoozed": 0, "completed": 0, "canceled": 0}
                total = 0
                for row in rows:
                    counts[row["status"]] = row["cnt"]
                    total += row["cnt"]

                days_data.append({
                    "date": target_date,
                    "active": counts["active"],
                    "snoozed": counts["snoozed"],
                    "completed": counts["completed"],
                    "canceled": counts["canceled"],
                    "total": total,
                })

        return {
            "ok": True,
            "data": {
                "month": month,
                "days": days_data,
            },
        }


@router.get("/events")
def list_events(date_value: str = Query(..., alias="date")) -> dict[str, object]:
    target_date = _normalize_date(date_value)

    with _db() as connection:
        user_id = _single_user_id(connection)

        rows = connection.execute(
            """
            SELECT e.* FROM goal_action_events e
            JOIN goals g ON e.goal_id = g.id
            WHERE g.user_id = ? AND DATE(e.created_at) = ?
            ORDER BY e.created_at DESC
            """,
            (user_id, target_date),
        ).fetchall()

        return {
            "ok": True,
            "data": {
                "date": target_date,
                "items": [_event_to_dto(row) for row in rows],
            },
        }


@router.put("/{goal_id}")
def update_goal(goal_id: int, payload: GoalUpdateIn) -> dict[str, object]:
    if payload.model_dump(exclude_none=True) == {}:
        raise APIError("VALIDATION_ERROR", "No fields provided for update", 400)

    with _db() as connection:
        user_id = _single_user_id(connection)
        goal = _fetch_goal(connection, user_id, goal_id)
        _assert_state(goal["status"], {"active", "snoozed"}, "update")

        title = _normalize_title(payload.title) if payload.title is not None else goal["title"]
        target_date = _normalize_date(payload.target_date) if payload.target_date is not None else goal["target_date"]
        target_time = _normalize_time(payload.target_time) if payload.target_time is not None else goal["target_time"]
        note = payload.note if payload.note is not None else goal["note"]
        priority = payload.priority if payload.priority is not None else goal["priority"]
        timestamp = now_iso()

        connection.execute(
            """
            UPDATE goals
            SET title = ?, note = ?, target_date = ?, target_time = ?, priority = ?, updated_at = ?
            WHERE id = ?
            """,
            (title, note, target_date, target_time, priority, timestamp, goal_id),
        )
        event = _create_event(connection, goal_id, "updated", "mobile")
        updated = connection.execute("SELECT * FROM goals WHERE id = ?", (goal_id,)).fetchone()
        connection.commit()

        if updated is None:
            raise APIError("INTERNAL_ERROR", "Goal update failed", 500)

        return {
            "ok": True,
            "data": {
                "goal": _goal_to_dto(updated),
                "event": _event_to_dto(event),
            },
        }


@router.post("/{goal_id}/complete")
def complete_goal(goal_id: int, _: ConfirmIn | None = None) -> dict[str, object]:
    with _db() as connection:
        user_id = _single_user_id(connection)
        goal = _fetch_goal(connection, user_id, goal_id)
        _assert_state(goal["status"], {"active", "snoozed"}, "complete")

        timestamp = now_iso()
        connection.execute(
            """
            UPDATE goals
            SET status = 'completed', completed_at = ?, snooze_until = NULL, updated_at = ?
            WHERE id = ?
            """,
            (timestamp, timestamp, goal_id),
        )
        event = _create_event(connection, goal_id, "completed", "mobile")
        updated = connection.execute("SELECT * FROM goals WHERE id = ?", (goal_id,)).fetchone()
        connection.commit()

        return {
            "ok": True,
            "data": {
                "goal": _goal_to_dto(updated),
                "event": _event_to_dto(event),
            },
        }


@router.post("/{goal_id}/snooze")
def snooze_goal(goal_id: int, payload: SnoozeIn) -> dict[str, object]:
    with _db() as connection:
        user_id = _single_user_id(connection)
        goal = _fetch_goal(connection, user_id, goal_id)
        _assert_state(goal["status"], {"active"}, "snooze")

        snooze_until = (
            datetime.now().astimezone() + timedelta(minutes=payload.minutes)
        ).isoformat(timespec="seconds")
        timestamp = now_iso()

        connection.execute(
            """
            UPDATE goals
            SET status = 'snoozed', snooze_until = ?, updated_at = ?
            WHERE id = ?
            """,
            (snooze_until, timestamp, goal_id),
        )
        event = _create_event(
            connection,
            goal_id,
            "snoozed",
            "mobile",
            {"minutes": payload.minutes, "snooze_until": snooze_until},
        )
        updated = connection.execute("SELECT * FROM goals WHERE id = ?", (goal_id,)).fetchone()
        connection.commit()

        return {
            "ok": True,
            "data": {
                "goal": _goal_to_dto(updated),
                "event": _event_to_dto(event),
            },
        }


@router.post("/{goal_id}/move-to-tomorrow")
def move_to_tomorrow(goal_id: int) -> dict[str, object]:
    with _db() as connection:
        user_id = _single_user_id(connection)
        goal = _fetch_goal(connection, user_id, goal_id)
        _assert_state(goal["status"], {"active", "snoozed"}, "move to tomorrow")

        old_date = date.fromisoformat(goal["target_date"])
        new_date = (old_date + timedelta(days=1)).isoformat()
        timestamp = now_iso()
        connection.execute(
            """
            UPDATE goals
            SET target_date = ?, status = 'active', snooze_until = NULL, reminder_ignore_count = 0, updated_at = ?
            WHERE id = ?
            """,
            (new_date, timestamp, goal_id),
        )
        event = _create_event(
            connection,
            goal_id,
            "moved_to_tomorrow",
            "mobile",
            {"from": goal["target_date"], "to": new_date},
        )
        updated = connection.execute("SELECT * FROM goals WHERE id = ?", (goal_id,)).fetchone()
        connection.commit()

        return {
            "ok": True,
            "data": {
                "goal": _goal_to_dto(updated),
                "event": _event_to_dto(event),
            },
        }


@router.post("/{goal_id}/cancel")
def cancel_goal(goal_id: int, _: ConfirmIn | None = None) -> dict[str, object]:
    with _db() as connection:
        user_id = _single_user_id(connection)
        goal = _fetch_goal(connection, user_id, goal_id)
        _assert_state(goal["status"], {"active", "snoozed"}, "cancel")

        timestamp = now_iso()
        connection.execute(
            """
            UPDATE goals
            SET status = 'canceled', canceled_at = ?, snooze_until = NULL, updated_at = ?
            WHERE id = ?
            """,
            (timestamp, timestamp, goal_id),
        )
        event = _create_event(connection, goal_id, "canceled", "mobile")
        updated = connection.execute("SELECT * FROM goals WHERE id = ?", (goal_id,)).fetchone()
        connection.commit()

        return {
            "ok": True,
            "data": {
                "goal": _goal_to_dto(updated),
                "event": _event_to_dto(event),
            },
        }
