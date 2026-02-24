from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


DDL = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    telegram_id TEXT UNIQUE,
    display_name TEXT,
    timezone TEXT NOT NULL DEFAULT 'Europe/Paris',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS goals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    note TEXT,
    target_date TEXT NOT NULL,
    target_time TEXT,
    priority TEXT,
    status TEXT NOT NULL CHECK (status IN ('active', 'snoozed', 'completed', 'canceled')),
    snooze_until TEXT,
    created_from TEXT NOT NULL CHECK (created_from IN ('telegram', 'mobile')),
    last_reminded_at TEXT,
    reminder_ignore_count INTEGER NOT NULL DEFAULT 0,
    completed_at TEXT,
    canceled_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_goals_user_target_date ON goals(user_id, target_date);
CREATE INDEX IF NOT EXISTS idx_goals_user_target_date_status ON goals(user_id, target_date, status);
CREATE INDEX IF NOT EXISTS idx_goals_status ON goals(status);
CREATE INDEX IF NOT EXISTS idx_goals_snooze_until ON goals(snooze_until);

CREATE TABLE IF NOT EXISTS reminder_policies (
    user_id INTEGER PRIMARY KEY,
    active_window_start TEXT NOT NULL,
    active_window_end TEXT NOT NULL,
    quiet_period_enabled INTEGER NOT NULL,
    quiet_period_start TEXT,
    quiet_period_end TEXT,
    interval_minutes INTEGER NOT NULL,
    default_snooze_options TEXT NOT NULL,
    sound_enabled INTEGER NOT NULL,
    persistence_mode TEXT NOT NULL CHECK (persistence_mode IN ('soft', 'normal', 'hard')),
    escalation_enabled INTEGER NOT NULL,
    escalation_step_minutes INTEGER,
    global_pause_until TEXT,
    ask_about_auto_moved_morning INTEGER NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS goal_action_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    goal_id INTEGER NOT NULL,
    action_type TEXT NOT NULL,
    action_payload TEXT,
    source TEXT NOT NULL CHECK (source IN ('telegram', 'mobile', 'backend_auto')),
    created_at TEXT NOT NULL,
    FOREIGN KEY (goal_id) REFERENCES goals(id)
);

CREATE INDEX IF NOT EXISTS idx_events_goal_id ON goal_action_events(goal_id);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON goal_action_events(created_at);
CREATE INDEX IF NOT EXISTS idx_events_action_type ON goal_action_events(action_type);
"""


DEFAULT_POLICY = {
    "active_window_start": "09:00",
    "active_window_end": "21:00",
    "quiet_period_enabled": 1,
    "quiet_period_start": "14:00",
    "quiet_period_end": "17:00",
    "interval_minutes": 30,
    "default_snooze_options": json.dumps([10, 30, 60]),
    "sound_enabled": 1,
    "persistence_mode": "soft",
    "escalation_enabled": 1,
    "escalation_step_minutes": 5,
    "global_pause_until": None,
    "ask_about_auto_moved_morning": 1,
}


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def get_connection(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(db_path)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON;")
    return connection


def init_db(db_path: Path) -> None:
    with get_connection(db_path) as connection:
        connection.executescript(DDL)
        connection.commit()


def seed_single_user_defaults(db_path: Path) -> None:
    timestamp = now_iso()
    with get_connection(db_path) as connection:
        user = connection.execute(
            "SELECT id FROM users ORDER BY id LIMIT 1"
        ).fetchone()

        if user is None:
            cursor = connection.execute(
                """
                INSERT INTO users (telegram_id, display_name, timezone, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (None, "MVP User", "Europe/Paris", timestamp, timestamp),
            )
            user_id = int(cursor.lastrowid)
        else:
            user_id = int(user["id"])

        policy = connection.execute(
            "SELECT user_id FROM reminder_policies WHERE user_id = ?", (user_id,)
        ).fetchone()

        if policy is None:
            connection.execute(
                """
                INSERT INTO reminder_policies (
                    user_id,
                    active_window_start,
                    active_window_end,
                    quiet_period_enabled,
                    quiet_period_start,
                    quiet_period_end,
                    interval_minutes,
                    default_snooze_options,
                    sound_enabled,
                    persistence_mode,
                    escalation_enabled,
                    escalation_step_minutes,
                    global_pause_until,
                    ask_about_auto_moved_morning,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    user_id,
                    DEFAULT_POLICY["active_window_start"],
                    DEFAULT_POLICY["active_window_end"],
                    DEFAULT_POLICY["quiet_period_enabled"],
                    DEFAULT_POLICY["quiet_period_start"],
                    DEFAULT_POLICY["quiet_period_end"],
                    DEFAULT_POLICY["interval_minutes"],
                    DEFAULT_POLICY["default_snooze_options"],
                    DEFAULT_POLICY["sound_enabled"],
                    DEFAULT_POLICY["persistence_mode"],
                    DEFAULT_POLICY["escalation_enabled"],
                    DEFAULT_POLICY["escalation_step_minutes"],
                    DEFAULT_POLICY["global_pause_until"],
                    DEFAULT_POLICY["ask_about_auto_moved_morning"],
                    timestamp,
                ),
            )

        connection.commit()
