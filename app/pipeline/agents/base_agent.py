import hashlib
import logging
import time
from datetime import datetime, timezone
from typing import List

from app.config import settings
from app.pipeline.state import ArticleData, PipelineState
from app.services import groq_client, tavily_client, newsapi_client, embedder, scraper

_INTER_ARTICLE_DELAY = 2  # seconds between Groq calls to stay within rate limit

logger = logging.getLogger(__name__)


class BaseAgent:
    domain: str = ""
    tavily_queries: List[str] = []
    newsapi_keywords: List[str] = []

    def run(self, state: PipelineState) -> dict:
        articles: List[ArticleData] = []
        errors: List[dict] = []
        now = datetime.now(timezone.utc).isoformat()

        raw_items = self._fetch_all(errors, now)

        for item in raw_items:
            if not item["url"] or not item["title"]:
                continue
            try:
                time.sleep(_INTER_ARTICLE_DELAY)
                content = scraper.enrich_content(item["url"], item["content"])
                summary_data = groq_client.summarize(content)
                embedding = embedder.embed(item["title"] + " " + summary_data["summary"])
                content_hash = hashlib.sha256(item["url"].encode()).hexdigest()

                articles.append(ArticleData(
                    title=item["title"],
                    url=item["url"],
                    raw_content=content,
                    domain=self.domain,
                    source=item["source"],
                    fetched_at=now,
                    summary=summary_data["summary"],
                    tags=summary_data.get("tags", []),
                    embedding=embedding,
                    content_hash=content_hash,
                ))
            except Exception as exc:
                errors.append({
                    "domain": self.domain,
                    "url": item.get("url", ""),
                    "error": str(exc),
                })

        return {"raw_articles": articles, "errors": errors}

    def _fetch_all(self, errors: list, now: str) -> List[dict]:
        items: List[dict] = []
        seen_urls: set = set()

        for query in self.tavily_queries[:settings.tavily_queries_per_agent]:
            try:
                for r in tavily_client.search(query):
                    if r["url"] and r["url"] not in seen_urls:
                        seen_urls.add(r["url"])
                        items.append(r)
            except Exception as exc:
                errors.append({"domain": self.domain, "url": "", "error": f"tavily: {exc}"})

        for keyword in self.newsapi_keywords:
            try:
                for r in newsapi_client.get_india_headlines(keyword):
                    if r["url"] and r["url"] not in seen_urls:
                        seen_urls.add(r["url"])
                        items.append(r)
            except Exception as exc:
                errors.append({"domain": self.domain, "url": "", "error": f"newsapi: {exc}"})

        return items
