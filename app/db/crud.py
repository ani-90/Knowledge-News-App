import json
from datetime import datetime
from typing import List, Optional  # noqa: F401 — Optional used in create_user signature

from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.models import Article, PipelineRun, QuizSession, ReadingHistory, User


# --- Users ---

def get_or_create_user(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        user = User(id=user_id, email=f"user{user_id}@local", display_name=f"User {user_id}")
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def create_user(db: Session, display_name: str, email: Optional[str] = None) -> User:
    if email:
        existing = db.query(User).filter(User.email == email).first()
        if existing:
            return existing
    generated_id = db.query(func.max(User.id)).scalar() or 0
    new_id = generated_id + 1
    email = email or f"user{new_id}@local"
    user = User(id=new_id, email=email, display_name=display_name)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# --- Articles ---

def bulk_insert_articles(db: Session, articles: List[dict]) -> List[Article]:
    objs = []
    for a in articles:
        existing = db.query(Article).filter(Article.url == a["url"]).first()
        if existing:
            continue
        obj = Article(
            qdrant_id=a["qdrant_id"],
            url=a["url"],
            title=a["title"],
            summary=a["summary"],
            domain=a["domain"],
            source=a["source"],
            tags=json.dumps(a.get("tags", [])),
            raw_content=a.get("raw_content", ""),
            fetched_at=a.get("fetched_at"),
        )
        db.add(obj)
        objs.append(obj)
    db.commit()
    return objs


def get_article(db: Session, article_id: int) -> Optional[Article]:
    return db.query(Article).filter(Article.id == article_id).first()


def get_articles_by_qdrant_ids(db: Session, qdrant_ids: List[str]) -> dict:
    """Return {qdrant_id: sqlite_id} for the given list of qdrant_ids."""
    rows = db.query(Article.qdrant_id, Article.id).filter(Article.qdrant_id.in_(qdrant_ids)).all()
    return {qdrant_id: sqlite_id for qdrant_id, sqlite_id in rows}


def get_articles_by_urls(db: Session, urls: List[str]) -> dict:
    """Return {url: sqlite_id} for the given list of URLs."""
    rows = db.query(Article.url, Article.id).filter(Article.url.in_(urls)).all()
    return {url: sqlite_id for url, sqlite_id in rows}


# --- Pipeline Runs ---

def create_pipeline_run(db: Session, run_id: str, user_id: int, domains: List[str]) -> PipelineRun:
    run = PipelineRun(
        run_id=run_id,
        user_id=user_id,
        domains=json.dumps(domains),
        status="queued",
        started_at=datetime.utcnow(),
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return run


def update_pipeline_run(db: Session, run_id: str, **kwargs) -> None:
    db.query(PipelineRun).filter(PipelineRun.run_id == run_id).update(kwargs)
    db.commit()


def get_pipeline_run(db: Session, run_id: str) -> Optional[PipelineRun]:
    return db.query(PipelineRun).filter(PipelineRun.run_id == run_id).first()


# --- Quiz Sessions ---

def create_quiz_session(db: Session, user_id: int, article_id: int, domain: str, questions: list) -> QuizSession:
    session = QuizSession(
        user_id=user_id,
        article_id=article_id,
        domain=domain,
        questions_json=json.dumps(questions),
        total_questions=len(questions),
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def submit_quiz_session(db: Session, session_id: int, user_answers: dict) -> QuizSession:
    session = db.query(QuizSession).filter(QuizSession.id == session_id).first()
    if not session:
        return None
    questions = json.loads(session.questions_json)
    correct = sum(
        1 for i, q in enumerate(questions)
        if user_answers.get(str(i), "").upper() == q["answer"].upper()
    )
    session.user_answers = json.dumps(user_answers)
    session.correct_count = correct
    session.total_questions = len(questions)
    session.score = correct / len(questions) if questions else 0.0
    session.submitted_at = datetime.utcnow()
    db.commit()
    db.refresh(session)
    return session


def get_quiz_session(db: Session, session_id: int) -> Optional[QuizSession]:
    return db.query(QuizSession).filter(QuizSession.id == session_id).first()


# --- Reading History ---

def mark_read(db: Session, user_id: int, article_id: int, duration: Optional[int] = None) -> ReadingHistory:
    entry = ReadingHistory(user_id=user_id, article_id=article_id, read_duration_seconds=duration)
    db.add(entry)
    db.commit()
    return entry


# --- User Stats ---

def get_user_stats(db: Session, user_id: int) -> dict:
    total_read = db.query(func.count(ReadingHistory.id)).filter(ReadingHistory.user_id == user_id).scalar()
    total_quizzes = db.query(func.count(QuizSession.id)).filter(
        QuizSession.user_id == user_id, QuizSession.submitted_at.isnot(None)
    ).scalar()
    avg_score = db.query(func.avg(QuizSession.score)).filter(
        QuizSession.user_id == user_id, QuizSession.submitted_at.isnot(None)
    ).scalar()

    domain_scores = (
        db.query(QuizSession.domain, func.avg(QuizSession.score))
        .filter(QuizSession.user_id == user_id, QuizSession.submitted_at.isnot(None))
        .group_by(QuizSession.domain)
        .all()
    )

    return {
        "total_articles_read": total_read or 0,
        "total_quizzes_taken": total_quizzes or 0,
        "average_quiz_score": round(avg_score, 3) if avg_score else 0.0,
        "scores_by_domain": {d: round(s, 3) for d, s in domain_scores},
    }
