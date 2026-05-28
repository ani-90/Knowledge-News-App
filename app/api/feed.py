import json
from uuid import uuid4

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.sqlite import get_db
from app.db import crud
from app.db.models import Article as ArticleModel
from app.schemas.feed import FeedRefreshRequest, FeedRefreshResponse, ArticleResponse, ArticleDetailResponse, FeedResponse
from app.services import groq_client
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

    if domain:
        db_articles = crud.get_articles_by_domain(db, domain, limit=limit)
    else:
        db_articles = crud.get_all_recent_articles(db, limit=limit)

    articles = [
        ArticleResponse(
            id=a.id,
            qdrant_id=a.qdrant_id,
            title=a.title,
            url=a.url,
            summary=a.summary,
            domain=a.domain,
            source=a.source,
            tags=json.loads(a.tags or "[]"),
            fetched_at=a.fetched_at,
        )
        for a in db_articles
    ]

    return FeedResponse(domain=domain, articles=articles, total=len(articles))


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


@router.post("/{article_id}/summarize")
def summarize_article(article_id: int, db: Session = Depends(get_db)):
    article = crud.get_article(db, article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")
    if article.summary and article.summary.strip():
        return {"summary": article.summary, "cached": True}
    result = groq_client.summarize(article.raw_content or "")
    crud.update_article_summary(db, article_id, result["summary"], result.get("tags", []))
    return {"summary": result["summary"], "cached": False}


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
