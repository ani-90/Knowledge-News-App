import json
from datetime import datetime, timezone
from uuid import uuid4

from app.db.sqlite import SessionLocal
from app.db import crud
from app.pipeline.state import PipelineState


def aggregator_node(state: PipelineState) -> dict:
    articles = state.get("raw_articles", [])
    run_id = state["run_id"]

    sqlite_records = []

    for article in articles:
        if not article.url:
            continue

        sqlite_records.append({
            "qdrant_id": str(uuid4()),
            "url": article.url,
            "title": article.title,
            "summary": article.summary,
            "domain": article.domain,
            "source": article.source,
            "tags": article.tags,
            "raw_content": article.raw_content,
            "fetched_at": datetime.fromisoformat(article.fetched_at.replace("Z", "+00:00"))
                if article.fetched_at else None,
        })

    persisted = 0
    if sqlite_records:
        db = SessionLocal()
        try:
            inserted = crud.bulk_insert_articles(db, sqlite_records)
            persisted = len(inserted)
        finally:
            db.close()

    duplicates = len(sqlite_records) - persisted
    errors = state.get("errors", [])
    finished = datetime.now(timezone.utc).isoformat()
    status = "success" if not errors else ("partial" if persisted > 0 else "failed")

    db = SessionLocal()
    try:
        crud.update_pipeline_run(
            db,
            run_id,
            status=status,
            persisted_count=persisted,
            duplicate_count=duplicates,
            error_log=json.dumps(errors),
            finished_at=datetime.now(timezone.utc),
        )
    finally:
        db.close()

    return {
        "persisted_count": persisted,
        "duplicate_count": duplicates,
        "finished_at": finished,
        "status": status,
    }
