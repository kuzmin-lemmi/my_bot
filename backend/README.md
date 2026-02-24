# Backend (Phase 1)

FastAPI backend skeleton with SQLite schema initialization for MVP.

## Run

1. Install dependencies:
   - `pip install -r backend/requirements.txt`
2. Initialize DB manually (optional, app also does this on startup):
   - `python -m app.db_init`
3. Start server from `backend` directory:
   - `uvicorn app.main:app --reload`

## Implemented in Phase 1

- FastAPI app bootstrap (`app/main.py`)
- Logging setup (`app/logging_config.py`)
- SQLite schema init (`app/db.py`)
- Tables:
  - `users`
  - `goals`
  - `reminder_policies`
  - `goal_action_events`
- Seed default reminder policy for single-user mode
- Health endpoint: `GET /health`

## Implemented in Stage 2

- Goals API:
  - `POST /api/goals`
  - `POST /api/goals/batch`
  - `GET /api/goals?date=YYYY-MM-DD`
  - `PUT /api/goals/{id}`
  - `POST /api/goals/{id}/complete`
  - `POST /api/goals/{id}/snooze`
  - `POST /api/goals/{id}/move-to-tomorrow`
  - `POST /api/goals/{id}/cancel`
- Validation of state transitions according to state machine
- Action event logging for all goal mutations
