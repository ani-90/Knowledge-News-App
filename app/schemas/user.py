from typing import Dict, Optional
from pydantic import BaseModel, EmailStr


class UserCreateRequest(BaseModel):
    display_name: str
    email: Optional[str] = None


class UserResponse(BaseModel):
    user_id: int
    display_name: str
    email: str


class UserStatsResponse(BaseModel):
    user_id: int
    total_articles_read: int
    total_quizzes_taken: int
    average_quiz_score: float
    scores_by_domain: Dict[str, float]
