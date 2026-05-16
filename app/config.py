from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    groq_api_key: str
    tavily_api_key: str
    newsapi_key: str

    groq_model: str = "llama-3.3-70b-versatile"
    groq_max_tokens: int = 1024

    qdrant_path: str = "./qdrant_data"
    qdrant_collection: str = "articles"
    embedding_model: str = "all-MiniLM-L6-v2"

    sqlite_url: str = "sqlite:///./knowledge_news.db"

    articles_per_source: int = 3
    tavily_queries_per_agent: int = 2  # use only the top N queries per agent to limit volume
    similarity_threshold: float = 0.95


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
