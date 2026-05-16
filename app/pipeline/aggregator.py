import json
from datetime import datetime, timezone
from uuid import uuid4

from app.db.sqlite import SessionLocal
from app.db import crud, qdrant as qdrant_db
from app.pipeline.state import ArticleData, PipelineState


def aggregator_node(state: PipelineState) -> dict:
    articles = state.get("raw_articles", [])
    run_id = state["run_id"]

    persisted = 0
    duplicates = 0
    qdrant_points = []
    sqlite_records = []

    for article in articles:
        if not article.embedding or not article.url:
            continue

        # Cross-domain dedup via Qdrant similarity search
        hits = qdrant_db.search_similar(article.embedding)
        if hits:
            duplicates += 1
            continue

        qdrant_id = str(uuid4())
        article.qdrant_id = qdrant_id

        qdrant_points.append({
            "vector": article.embedding,
            "title": article.title,
            "url": article.url,
            "summary": article.summary,
            "domain": article.domain,
            "tags": article.tags,
            "source": article.source,
            "fetched_at": article.fetched_at,
            "qdrant_id": qdrant_id,
        })

        sqlite_records.append({
            "qdrant_id": qdrant_id,
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

    # Bulk insert to SQLite first so we can capture sqlite_ids
    if sqlite_records:
        db = SessionLocal()
        try:
            inserted = crud.bulk_insert_articles(db, sqlite_records)
            # Map qdrant_id → sqlite_id for Qdrant payload enrichment
            id_map = {obj.qdrant_id: obj.id for obj in inserted if obj.id}
        finally:
            db.close()
        for point in qdrant_points:
            point["sqlite_id"] = id_map.get(point["qdrant_id"])

    # Upsert to Qdrant
    if qdrant_points:
        persisted = qdrant_db.upsert_articles(qdrant_points)

    # Update pipeline run record
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
