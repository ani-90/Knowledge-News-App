from datetime import datetime
from typing import Dict, List, Optional
from pydantic import BaseModel


class QuizGenerateRequest(BaseModel):
    article_id: int
    user_id: int = 1


class QuizOption(BaseModel):
    A: str
    B: str
    C: str
    D: str


class QuizQuestion(BaseModel):
    question: str
    options: QuizOption
    explanation: Optional[str] = None
    # 'answer' is intentionally excluded from the response to the client


class QuizGenerateResponse(BaseModel):
    session_id: int
    article_id: int
    domain: str
    questions: List[QuizQuestion]


class QuizSubmitRequest(BaseModel):
    session_id: int
    answers: Dict[str, str]  # {"0": "B", "1": "A", "2": "C"}


class QuizAnswerBreakdown(BaseModel):
    question: str
    your_answer: str
    correct_answer: str
    is_correct: bool
    explanation: str


class QuizSubmitResponse(BaseModel):
    session_id: int
    score: float
    correct_count: int
    total_questions: int
    breakdown: List[QuizAnswerBreakdown]
