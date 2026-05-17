import json
from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.sqlite import get_db
from app.db import crud, qdrant as qdrant_db
from app.db.models import Article as ArticleModel
from app.schemas.feed import FeedRefreshRequest, FeedRefreshResponse, ArticleResponse, ArticleDetailResponse, FeedResponse
from app.config import DOMAINS

router = APIRouter(prefix="/api/feed", tags=["feed"])


@router.post("/refresh", response_model=FeedRefreshResponse)
async def refresh_feed(
    request: FeedRefreshRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    domains = request.resolved_domains()
    run_id = str(uuid4())

    crud.create_pipeline_run(db, run_id, request.user_id, domains)
    crud.update_pipeline_run(db, run_id, status="running")

    background_tasks.add_task(_run_pipeline_bg, run_id, request.user_id, domains)

    return FeedRefreshResponse(run_id=run_id, status="running", domains=domains)


async def _run_pipeline_bg(run_id: str, user_id: int, domains: list) -> None:
    from app.pipeline.graph import run_pipeline
    try:
        await run_pipeline(run_id, user_id, domains)
    except Exception as exc:
        from app.db.sqlite import SessionLocal
        from datetime import datetime, timezone
        db = SessionLocal()
        try:
            crud.update_pipeline_run(
                db,
                run_id,
                status="failed",
                error_log=json.dumps([{"error": str(exc)}]),
                finished_at=datetime.now(timezone.utc),
            )
        finally:
            db.close()


@router.get("/status/{run_id}")
def get_run_status(run_id: str, db: Session = Depends(get_db)):
    run = crud.get_pipeline_run(db, run_id)
    if not run:
        raise HTTPException(status_code=404, detail="Run not found")
    return {
        "run_id": run.run_id,
        "status": run.status,
        "persisted_count": run.persisted_count,
        "duplicate_count": run.duplicate_count,
        "started_at": run.started_at,
        "finished_at": run.finished_at,
        "errors": json.loads(run.error_log or "[]"),
    }


@router.get("", response_model=FeedResponse)
def get_feed(
    domain: str = Query(None, description=f"One of: {', '.join(DOMAINS)}"),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    if domain and domain not in DOMAINS:
        raise HTTPException(status_code=400, detail=f"Unknown domain. Choose from: {DOMAINS}")

    try:
        if domain:
            records = qdrant_db.get_by_domain(domain, limit=limit)
        else:
            records = qdrant_db.get_all_recent(limit=limit)
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Vector store error: {exc}")

    # Build articles with sqlite_id from Qdrant payload when available
    raw_articles = []
    needs_lookup = []
    for r in records:
        p = r.payload or {}
        qdrant_id = str(r.id)
        # payload qdrant_id matches SQLite; may differ from r.id for older points
        payload_qdrant_id = p.get("qdrant_id", qdrant_id)
        sqlite_id = p.get("sqlite_id")
        raw_articles.append((qdrant_id, payload_qdrant_id, sqlite_id, p))
        if sqlite_id is None:
            needs_lookup.append(payload_qdrant_id)

    # Fallback 1: lookup SQLite ids by qdrant_id for articles without sqlite_id in payload
    id_map: dict = {}
    if needs_lookup:
        id_map = crud.get_articles_by_qdrant_ids(db, needs_lookup)

    # Fallback 2: for articles still unresolved, lookup by URL
    still_missing_urls = [
        p.get("url") for _, payload_qdrant_id, sqlite_id, p in raw_articles
        if sqlite_id is None and id_map.get(payload_qdrant_id) is None and p.get("url")
    ]
    url_map: dict = {}
    if still_missing_urls:
        url_map = crud.get_articles_by_urls(db, still_missing_urls)

    articles = []
    for qdrant_id, payload_qdrant_id, sqlite_id, p in raw_articles:
        resolved_id = sqlite_id or id_map.get(payload_qdrant_id) or url_map.get(p.get("url"))
        articles.append(ArticleResponse(
            id=resolved_id,
            qdrant_id=qdrant_id,
            title=p.get("title", ""),
            url=p.get("url", ""),
            summary=p.get("summary", ""),
            domain=p.get("domain", domain or ""),
            source=p.get("source", ""),
            tags=p.get("tags", []),
            fetched_at=p.get("fetched_at"),
        ))

    # Sort by fetched_at descending (newest first); use datetime.min for None so they sink to the bottom
    _min_dt = datetime.min.replace(tzinfo=timezone.utc)
    articles.sort(key=lambda a: a.fetched_at or _min_dt, reverse=True)

    # Deduplicate by URL — Qdrant may hold multiple points for the same URL from different pipeline runs
    seen_urls: set = set()
    deduped = []
    for a in articles:
        if a.url not in seen_urls:
            seen_urls.add(a.url)
            deduped.append(a)

    return FeedResponse(domain=domain, articles=deduped, total=len(deduped))


def _is_quality_content(text: str) -> bool:
    """Return False if text looks like scraped navigation/UI rather than article prose."""
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    if not lines:
        return False
    avg_words = sum(len(l.split()) for l in lines) / len(lines)
    return avg_words >= 7  # navigation menus have short lines; real prose averages 7+ words


@router.get("/{article_id}", response_model=ArticleDetailResponse)
def get_article_detail(article_id: int, db: Session = Depends(get_db)):
    from app.services import scraper
    article = crud.get_article(db, article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")

    raw_content = article.raw_content or ""

    # Re-scrape on demand if stored content is too short or is navigation junk
    if (len(raw_content.strip()) < 500 or not _is_quality_content(raw_content)) and article.url:
        enriched = scraper.enrich_content(article.url, raw_content)
        if len(enriched) > len(raw_content) and _is_quality_content(enriched):
            raw_content = enriched
            db.query(ArticleModel).filter_by(id=article_id).update({"raw_content": raw_content})
            db.commit()
        elif not _is_quality_content(raw_content):
            # Content is junk and re-scrape didn't help — return empty so client shows summary
            raw_content = ""

    return ArticleDetailResponse(
        id=article.id,
        qdrant_id=article.qdrant_id,
        title=article.title,
        url=article.url,
        summary=article.summary,
        raw_content=raw_content,
        domain=article.domain,
        source=article.source,
        tags=json.loads(article.tags or "[]"),
        fetched_at=article.fetched_at,
    )


@router.post("/{article_id}/read")
def mark_article_read(
    article_id: int,
    user_id: int = Query(1),
    duration_seconds: int = Query(None),
    db: Session = Depends(get_db),
):
    article = crud.get_article(db, article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")
    crud.mark_read(db, user_id, article_id, duration_seconds)
    return {"status": "ok"}
