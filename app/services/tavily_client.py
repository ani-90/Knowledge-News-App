from typing import List

from tavily import TavilyClient

from app.config import settings

_client = TavilyClient(api_key=settings.tavily_api_key)


def search(query: str, max_results: int = None) -> List[dict]:
    """Returns list of {url, title, content, score}"""
    if max_results is None:
        max_results = settings.articles_per_source
    try:
        response = _client.search(
            query=query,
            search_depth="advanced",
            topic="news",
            max_results=max_results,
            include_raw_content=True,
        )
        results = []
        for r in response.get("results", []):
            # Prefer raw_content (full page) over the truncated content snippet
            content = r.get("raw_content") or r.get("content", "")
            results.append({
                "url": r.get("url", ""),
                "title": r.get("title", ""),
                "content": content,
                "source": "tavily",
            })
        return results
    except Exception:
        return []
