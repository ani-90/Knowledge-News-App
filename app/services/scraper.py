import logging

import trafilatura

logger = logging.getLogger(__name__)

_MIN_CONTENT_LENGTH = 300


def _fetch_and_extract(url: str) -> str:
    """Download URL and extract main article text via trafilatura."""
    try:
        downloaded = trafilatura.fetch_url(url)
        if not downloaded:
            return ""
        text = trafilatura.extract(
            downloaded,
            include_comments=False,
            include_tables=False,
            no_fallback=False,
        )
        return text or ""
    except Exception as exc:
        logger.debug("trafilatura failed for %s: %s", url, exc)
        return ""


def enrich_content(url: str, existing_content: str) -> str:
    """Return existing_content if long enough, otherwise scrape the URL with trafilatura."""
    if len(existing_content.strip()) >= _MIN_CONTENT_LENGTH:
        return existing_content
    scraped = _fetch_and_extract(url)
    if len(scraped) > len(existing_content):
        logger.debug("Scraped %d chars from %s", len(scraped), url)
        return scraped[:8000]
    return existing_content