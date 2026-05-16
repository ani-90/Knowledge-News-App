import operator
from dataclasses import dataclass, field
from typing import Annotated, List, Optional
from typing_extensions import TypedDict


@dataclass
class ArticleData:
    title: str
    url: str
    raw_content: str
    domain: str
    source: str
    fetched_at: str

    summary: str = ""
    tags: List[str] = field(default_factory=list)
    embedding: Optional[List[float]] = None
    content_hash: str = ""
    qdrant_id: str = ""


class PipelineState(TypedDict):
    user_id: int
    domains_requested: List[str]
    run_id: str
    started_at: str

    # operator.add merges lists from parallel agent branches
    raw_articles: Annotated[List[ArticleData], operator.add]
    errors: Annotated[List[dict], operator.add]

    persisted_count: int
    duplicate_count: int
    finished_at: str
    status: str
