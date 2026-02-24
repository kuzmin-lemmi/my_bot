from __future__ import annotations

from app.config import get_settings
from app.db import init_db, seed_single_user_defaults


def main() -> None:
    settings = get_settings()
    init_db(settings.db_path)
    seed_single_user_defaults(settings.db_path)
    print(f"Database initialized at: {settings.db_path}")


if __name__ == "__main__":
    main()
