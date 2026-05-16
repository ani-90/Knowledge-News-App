import json
import re
import time
import logging
import threading
from typing import List

from groq import Groq, RateLimitError

from app.config import settings

logger = logging.getLogger(__name__)
_client = Groq(api_key=settings.groq_api_key)

_MAX_RETRIES = 4
_RETRY_BASE_SECONDS = 8  # wait 8, 16, 32, 64s on successive 429s

# Limit concurrent Groq calls across all parallel agents to avoid hammering the rate limit
_semaphore = threading.Semaphore(2)

_SUMMARIZE_SYSTEM = (
    "You are a concise news analyst for educated Indian readers. "
    "Given an article, return ONLY valid JSON with this shape: "
    '{"summary": "<3-4 sentence summary>", "tags": ["<tag1>", "<tag2>", "<tag3>"]}. '
    "Tags should be short, relevant keywords. No markdown, no extra text."
)

_QUIZ_SYSTEM = (
    "You are a quiz master creating comprehension questions for Indian news readers. "
    "Given a news summary, generate exactly 3 multiple-choice questions. "
    "Return ONLY a valid JSON array with this shape: "
    '[{"question":"...","options":{"A":"...","B":"...","C":"...","D":"..."},'
    '"answer":"<A|B|C|D>","explanation":"..."}]. '
    "No markdown, no extra text."
)


def _call(system: str, user: str) -> str:
    with _semaphore:  # at most 2 concurrent Groq calls across all agents
      for attempt in range(_MAX_RETRIES):
        try:
            response = _client.chat.completions.create(
                model=settings.groq_model,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                max_tokens=settings.groq_max_tokens,
                temperature=0.3,
            )
            return response.choices[0].message.content.strip()
        except RateLimitError:
            wait = _RETRY_BASE_SECONDS * (2 ** attempt)
            logger.warning("Groq 429 rate limit — waiting %ds (attempt %d/%d)", wait, attempt + 1, _MAX_RETRIES)
            time.sleep(wait)
    raise RuntimeError(f"Groq rate limit exceeded after {_MAX_RETRIES} retries")


def _extract_json(text: str):
    """Strip any markdown fences and parse JSON."""
    text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.MULTILINE)
    text = re.sub(r"\s*```$", "", text, flags=re.MULTILINE)
    return json.loads(text.strip())


def summarize(raw_content: str) -> dict:
    """Returns {"summary": str, "tags": List[str]}"""
    if not raw_content or not raw_content.strip():
        return {"summary": "No content available.", "tags": []}
    truncated = raw_content[:4000]
    raw = _call(_SUMMARIZE_SYSTEM, truncated)
    try:
        result = _extract_json(raw)
        if "summary" not in result:
            result["summary"] = raw[:300]
        if "tags" not in result:
            result["tags"] = []
        return result
    except (json.JSONDecodeError, ValueError):
        return {"summary": raw[:300], "tags": []}


def generate_quiz(summary: str) -> List[dict]:
    """Returns list of 3 MCQ dicts: {question, options, answer, explanation}"""
    raw = _call(_QUIZ_SYSTEM, summary)
    try:
        questions = _extract_json(raw)
        if not isinstance(questions, list):
            return []
        return questions[:3]
    except (json.JSONDecodeError, ValueError):
        return []
