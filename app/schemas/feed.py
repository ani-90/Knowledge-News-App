from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel
from app.config import DOMAINS


class FeedRefreshRequest(BaseModel):
    user_id: int = 1
    domains: Optional[List[str]] = None  # defaults to all 7

    def resolved_domains(self) -> List[str]:
        if not self.domains:
            return DOMAINS
        return [d for d in self.domains if d in DOMAINS]


class FeedRefreshResponse(BaseModel):
    run_id: str
    status: str
    domains: List[str]


class ArticleResponse(BaseModel):
    id: Optional[int] = None
    qdrant_id: str
    title: str
    url: str
    summary: str
    domain: str
    source: str
    tags: List[str]
    fetched_at: Optional[datetime] = None


class ArticleDetailResponse(ArticleResponse):
    raw_content: str = ""


class FeedResponse(BaseModel):
    domain: Optional[str]
    articles: List[ArticleResponse]
    total: int
