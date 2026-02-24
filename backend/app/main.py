from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError

from app.api.goals import router as goals_router
from app.api.health import router as health_router
from app.api.reminder_policy import router as reminder_policy_router
from app.config import get_settings
from app.db import init_db, seed_single_user_defaults
from app.errors import APIError, api_error_handler, request_validation_error_handler
from app.logging_config import setup_logging

setup_logging()
logger = logging.getLogger(__name__)
settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    logger.info("Initializing database at %s", settings.db_path)
    init_db(settings.db_path)
    seed_single_user_defaults(settings.db_path)
    logger.info("Database initialized and seeded")
    yield


app = FastAPI(title=settings.app_name, version="0.1.0", lifespan=lifespan)
app.include_router(health_router)
app.include_router(goals_router)
app.include_router(reminder_policy_router)
app.add_exception_handler(APIError, api_error_handler)
app.add_exception_handler(RequestValidationError, request_validation_error_handler)
