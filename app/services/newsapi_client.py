from typing import List

from newsapi import NewsApiClient

from app.config import settings

_client = NewsApiClient(api_key=settings.newsapi_key)


def search(keyword: str, max_results: int = None) -> List[dict]:
    """Returns list of {url, title, content, source}"""
    if max_results is None:
        max_results = settings.articles_per_source
    try:
        response = _client.get_everything(
            q=keyword,
            language="en",
            sort_by="publishedAt",
            page_size=max_results,
        )
        results = []
        for article in response.get("articles", [])[:max_results]:
            content = " ".join(filter(None, [
                article.get("description", ""),
                article.get("content", ""),
            ]))
            results.append({
                "url": article.get("url", ""),
                "title": article.get("title", ""),
                "content": content,
                "source": "newsapi",
            })
        return results
    except Exception:
        return []


def get_india_headlines(keyword: str, max_results: int = None) -> List[dict]:
    if max_results is None:
        max_results = settings.articles_per_source
    try:
        response = _client.get_top_headlines(
            q=keyword,
            country="in",
            page_size=max_results,
        )
        results = []
        for article in response.get("articles", [])[:max_results]:
            content = " ".join(filter(None, [
                article.get("description", ""),
                article.get("content", ""),
            ]))
            results.append({
                "url": article.get("url", ""),
                "title": article.get("title", ""),
                "content": content,
                "source": "newsapi",
            })
        return results
    except Exception:
        return []
