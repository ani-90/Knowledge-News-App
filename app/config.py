from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    groq_api_key: str
    tavily_api_key: str
    newsapi_key: str

    groq_model: str = "llama-3.3-70b-versatile"
    groq_max_tokens: int = 1024

    # Qdrant — use cloud URL+key when set, otherwise fall back to local path
    qdrant_url: Optional[str] = None
    qdrant_api_key: Optional[str] = None
    qdrant_path: str = "./qdrant_data"
    qdrant_collection: str = "articles"

    embedding_model: str = "all-MiniLM-L6-v2"

    # Database — Railway sets DATABASE_URL for PostgreSQL; fall back to SQLite locally
    database_url: str = "sqlite:///./knowledge_news.db"

    articles_per_source: int = 5
    tavily_queries_per_agent: int = 5
    similarity_threshold: float = 0.85

    # Scheduler — 01:30 UTC = 07:00 IST; override via env vars on Railway
    schedule_hour: int = 7
    schedule_minute: int = 0


settings = Settings()

DOMAINS = [
    "finance",
    "politics",
    "ai_tech",
    "law",
    "health",
    "fashion",
    "dharma",
]
