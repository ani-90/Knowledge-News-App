import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.sqlite import get_db
from app.db import crud
from app.services import groq_client
from app.schemas.quiz import (
    QuizGenerateRequest,
    QuizGenerateResponse,
    QuizQuestion,
    QuizOption,
    QuizSubmitRequest,
    QuizSubmitResponse,
    QuizAnswerBreakdown,
)

router = APIRouter(prefix="/api/quiz", tags=["quiz"])


@router.post("/generate", response_model=QuizGenerateResponse)
def generate_quiz(request: QuizGenerateRequest, db: Session = Depends(get_db)):
    article = crud.get_article(db, request.article_id)
    if not article:
        raise HTTPException(status_code=404, detail="Article not found")

    raw_questions = groq_client.generate_quiz(article.summary)
    if not raw_questions:
        raise HTTPException(status_code=422, detail="LLM failed to generate quiz questions")

    session = crud.create_quiz_session(
        db,
        user_id=request.user_id,
        article_id=request.article_id,
        domain=article.domain,
        questions=raw_questions,
    )

    questions_out = []
    for q in raw_questions:
        opts = q.get("options", {})
        questions_out.append(QuizQuestion(
            question=q["question"],
            options=QuizOption(
                A=opts.get("A", ""),
                B=opts.get("B", ""),
                C=opts.get("C", ""),
                D=opts.get("D", ""),
            ),
            explanation=q.get("explanation"),
        ))

    return QuizGenerateResponse(
        session_id=session.id,
        article_id=request.article_id,
        domain=article.domain,
        questions=questions_out,
    )


@router.post("/submit", response_model=QuizSubmitResponse)
def submit_quiz(request: QuizSubmitRequest, db: Session = Depends(get_db)):
    session = crud.get_quiz_session(db, request.session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Quiz session not found")
    if session.submitted_at is not None:
        raise HTTPException(status_code=409, detail="Quiz already submitted")

    updated = crud.submit_quiz_session(db, request.session_id, request.answers)
    questions = json.loads(updated.questions_json)

    breakdown = []
    for i, q in enumerate(questions):
        user_ans = request.answers.get(str(i), "").upper()
        correct_ans = q["answer"].upper()
        breakdown.append(QuizAnswerBreakdown(
            question=q["question"],
            your_answer=user_ans,
            correct_answer=correct_ans,
            is_correct=user_ans == correct_ans,
            explanation=q.get("explanation", ""),
        ))

    return QuizSubmitResponse(
        session_id=updated.id,
        score=round(updated.score, 3),
        correct_count=updated.correct_count,
        total_questions=updated.total_questions,
        breakdown=breakdown,
    )
