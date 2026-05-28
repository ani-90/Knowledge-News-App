from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.sqlite import get_db
from app.db import crud
from app.services.groq_client import debate_reply
from app.schemas.debate import DebateRequest, DebateResponse

router = APIRouter(prefix="/api/debate", tags=["debate"])


@router.post("/message", response_model=DebateResponse)
def debate_message(request: DebateRequest, db: Session = Depends(get_db)):
    article = crud.get_article(db, request.article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")
    reply = debate_reply(
        article_title=article.title,
        article_content=article.raw_content or "",
        history=request.history,
        user_message=request.message,
    )
    return DebateResponse(reply=reply, turn=len(request.history) + 1)
