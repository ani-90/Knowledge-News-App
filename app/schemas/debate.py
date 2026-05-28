from typing import Dict, List
from pydantic import BaseModel


class DebateRequest(BaseModel):
    article_id: int
    user_id: int = 1
    message: str
    history: List[Dict[str, str]] = []


class DebateResponse(BaseModel):
    reply: str
    turn: int
