import asyncio
import logging
from uuid import uuid4
from datetime import datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

from app.config import DOMAINS

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler()


async def _daily_refresh():
    from app.pipeline.graph import run_pipeline
    from app.db.sqlite import SessionLocal
    from app.db import crud

    run_id = str(uuid4())
    logger.info("Scheduled daily refresh starting — run_id=%s", run_id)

    db = SessionLocal()
    try:
        crud.create_pipeline_run(db, run_id, user_id=1, domains=DOMAINS)
        crud.update_pipeline_run(db, run_id, status="running")
    finally:
        db.close()

    try:
        result = await run_pipeline(run_id, user_id=1, domains=DOMAINS)
        logger.info(
            "Scheduled refresh complete — persisted=%d dupes=%d status=%s",
            result.get("persisted_count", 0),
            result.get("duplicate_count", 0),
            result.get("status", "?"),
        )
    except Exception as exc:
        logger.error("Scheduled refresh failed: %s", exc)


def start_scheduler(hour: int = 7, minute: int = 0) -> None:
    """Start the daily refresh job. Defaults to 07:00 local time."""
    scheduler.add_job(
        _daily_refresh,
        trigger=CronTrigger(hour=hour, minute=minute),
        id="daily_refresh",
        replace_existing=True,
        misfire_grace_time=3600,  # run even if server was down for up to 1 hour
    )
    scheduler.start()
    next_run = scheduler.get_job("daily_refresh").next_run_time
    logger.info("Scheduler started — daily refresh at %02d:%02d, next run: %s", hour, minute, next_run)


def stop_scheduler() -> None:
    if scheduler.running:
        scheduler.shutdown(wait=False)
