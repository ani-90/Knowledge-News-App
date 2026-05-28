import json
import logging
from datetime import datetime, timezone
from uuid import uuid4

from app.db.sqlite import SessionLocal
from app.db import crud
from app.db.qdrant import search_similar, upsert_articles
from app.pipeline.state import PipelineState

logger = logging.getLogger(__name__)


def aggregator_node(state: PipelineState) -> dict:
    articles = state.get("raw_articles", [])
    run_id = state["run_id"]

    duplicate_count = 0
    db = SessionLocal()

    try:
        # Pass 1 — semantic dedup via Qdrant (catches paraphrased/syndicated duplicates)
        clean = []
        for article in articles:
            if article.embedding:
                matches = search_similar(article.embedding, threshold=0.85)
                if matches:
                    logger.debug("Semantic duplicate skipped: %s", article.url)
                    duplicate_count += 1
                    continue
            clean.append(article)

        # Pass 2 — build SQLite records and bulk insert (URL-exact dedup happens here)
        qdrant_id_map: dict[str, str] = {}
        sqlite_records = []
        for article in clean:
            qid = str(uuid4())
            qdrant_id_map[article.url] = qid
            sqlite_records.append({
                "qdrant_id": qid,
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

        inserted = crud.bulk_insert_articles(db, sqlite_records) if sqlite_records else []
        duplicate_count += len(clean) - len(inserted)
        persisted = len(inserted)

        # Pass 3 — upsert newly persisted articles to Qdrant
        url_to_embedding = {a.url: a.embedding for a in clean if a.embedding}
        qdrant_points = [
            {
                "qdrant_id": qdrant_id_map[db_article.url],
                "vector": url_to_embedding[db_article.url],
                "sqlite_id": db_article.id,
                "title": db_article.title,
                "domain": db_article.domain,
                "url": db_article.url,
            }
            for db_article in inserted
            if db_article.url in url_to_embedding and db_article.url in qdrant_id_map
        ]
        if qdrant_points:
            upsert_articles(qdrant_points)
            logger.info("Upserted %d vectors to Qdrant", len(qdrant_points))

        errors = state.get("errors", [])
        finished = datetime.now(timezone.utc).isoformat()
        status = "success" if not errors else ("partial" if persisted > 0 else "failed")

        crud.update_pipeline_run(
            db,
            run_id,
            status=status,
            persisted_count=persisted,
            duplicate_count=duplicate_count,
            error_log=json.dumps(errors),
            finished_at=datetime.now(timezone.utc),
        )
    finally:
        db.close()

    return {
        "persisted_count": persisted,
        "duplicate_count": duplicate_count,
        "finished_at": finished,
        "status": status,
    }
