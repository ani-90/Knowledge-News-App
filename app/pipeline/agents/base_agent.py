import hashlib
import logging
from datetime import datetime, timezone
from typing import List
from urllib.parse import urlparse, parse_qs, urlencode, urlunparse

from app.config import settings
from app.pipeline.state import ArticleData, PipelineState
from app.services import groq_client, tavily_client, newsapi_client, embedder, scraper

logger = logging.getLogger(__name__)

_STRIP_PARAMS = {
    "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
    "fbclid", "ref", "source", "_ga", "mc_cid", "mc_eid",
}


def _normalise_url(url: str) -> str:
    try:
        parsed = urlparse(url)
        clean_qs = {k: v for k, v in parse_qs(parsed.query).items() if k not in _STRIP_PARAMS}
        return urlunparse(parsed._replace(query=urlencode(clean_qs, doseq=True)))
    except Exception:
        return url


def _is_quality(content: str) -> bool:
    words = content.split()
    if len(words) < 40:
        return False
    lines = [l for l in content.splitlines() if l.strip()]
    if not lines:
        return False
    avg_words_per_line = sum(len(l.split()) for l in lines) / len(lines)
    return avg_words_per_line >= 5


class BaseAgent:
    domain: str = ""
    tavily_queries: List[str] = []
    newsapi_keywords: List[str] = []

    def run(self, state: PipelineState) -> dict:
        articles: List[ArticleData] = []
        errors: List[dict] = []
        now = datetime.now(timezone.utc).isoformat()

        raw_items = self._fetch_all(errors)

        for item in raw_items:
            if not item["url"] or not item["title"]:
                continue
            try:
                content = scraper.enrich_content(item["url"], item["content"])
                if not _is_quality(content):
                    logger.debug("Skipped (quality): %s", item["url"])
                    continue

                embedding = embedder.embed(item["title"] + " " + content[:500])
                content_hash = hashlib.sha256(item["url"].encode()).hexdigest()

                articles.append(ArticleData(
                    title=item["title"],
                    url=item["url"],
                    raw_content=content,
                    domain=self.domain,
                    source=item["source"],
                    fetched_at=now,
                    summary="",
                    tags=[],
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

    def _fetch_all(self, errors: list) -> List[dict]:
        items: List[dict] = []
        seen_urls: set = set()

        # Try LLM-generated queries for diversity; fall back to hardcoded
        try:
            live_queries = groq_client.generate_queries(self.domain, n=settings.tavily_queries_per_agent)
        except Exception as exc:
            logger.warning("Query generation failed for %s: %s — using hardcoded queries", self.domain, exc)
            live_queries = []
        queries = live_queries if live_queries else self.tavily_queries
        queries = queries[:settings.tavily_queries_per_agent]

        for query in queries:
            try:
                for r in tavily_client.search(query):
                    norm_url = _normalise_url(r["url"])
                    if norm_url and norm_url not in seen_urls:
                        seen_urls.add(norm_url)
                        r["url"] = norm_url
                        items.append(r)
            except Exception as exc:
                errors.append({"domain": self.domain, "url": "", "error": f"tavily: {exc}"})

        for keyword in self.newsapi_keywords:
            try:
                for r in newsapi_client.get_india_headlines(keyword):
                    norm_url = _normalise_url(r["url"])
                    if norm_url and norm_url not in seen_urls:
                        seen_urls.add(norm_url)
                        r["url"] = norm_url
                        items.append(r)
            except Exception as exc:
                errors.append({"domain": self.domain, "url": "", "error": f"newsapi: {exc}"})

        return items
