import re
import logging
import httpx

logger = logging.getLogger(__name__)

_MIN_CONTENT_LENGTH = 300
_SCRAPE_TIMEOUT = 8  # seconds
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0 Safari/537.36"
    )
}


def _strip_html(html: str) -> str:
    text = re.sub(r"<(script|style)[^>]*>.*?</(script|style)>", " ", html, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"&[a-zA-Z]+;", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def enrich_content(url: str, existing_content: str) -> str:
    """Return existing_content if it's long enough, otherwise scrape the URL."""
    if len(existing_content.strip()) >= _MIN_CONTENT_LENGTH:
        return existing_content
    try:
        with httpx.Client(timeout=_SCRAPE_TIMEOUT, headers=_HEADERS, follow_redirects=True) as client:
            resp = client.get(url)
            if resp.status_code == 200 and "text/html" in resp.headers.get("content-type", ""):
                scraped = _strip_html(resp.text)
                if len(scraped) > len(existing_content):
                    logger.debug("Scraped %d chars from %s", len(scraped), url)
                    return scraped[:8000]
    except Exception as exc:
        logger.debug("Scrape failed for %s: %s", url, exc)
    return existing_content
