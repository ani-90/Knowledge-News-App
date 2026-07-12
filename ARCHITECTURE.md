# Architecture

For high-level overview, stack, and setup see [README.md](./README.md).  
For engineering decisions and tradeoffs see [decisions and tradeoffs.md](./decisions%20and%20tradeoffs.md).

This document covers the internal detail: database schema, request flows, and rate limit strategy.

---

## 9. Database Schema

### `users`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | auto-increment |
| email | TEXT UNIQUE | |
| display_name | TEXT | |
| preferences | TEXT | JSON: `{domains, quiz_difficulty}` |
| created_at | DATETIME | |

### `articles`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | SQLite id returned by the feed API |
| qdrant_id | TEXT UNIQUE | UUID — links to Qdrant point |
| url | TEXT UNIQUE | dedup key within SQLite |
| title | TEXT | |
| summary | TEXT | Groq-generated 3–4 sentence summary |
| domain | TEXT | one of the 7 domains |
| source | TEXT | `"tavily"` or `"newsapi"` |
| tags | TEXT | JSON array of short keyword tags |
| raw_content | TEXT | scraped article text (not exposed via API) |
| fetched_at | DATETIME | |

### `reading_history`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| user_id | FK → users | |
| article_id | FK → articles | |
| read_at | DATETIME | |
| read_duration_seconds | INTEGER | optional, set by client |

### `quiz_sessions`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | returned as `session_id` |
| user_id | FK → users | |
| article_id | FK → articles | |
| domain | TEXT | copied from article for easy grouping |
| questions_json | TEXT | full Q&A blob including correct answers (server-side only) |
| user_answers | TEXT | JSON: `{"0":"B","1":"A","2":"C"}` — null until submitted |
| score | FLOAT | 0.0–1.0 |
| correct_count | INTEGER | |
| total_questions | INTEGER | |
| submitted_at | DATETIME | null = not yet submitted |

### `pipeline_runs`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| run_id | TEXT UNIQUE | UUID returned to caller |
| user_id | FK → users | who triggered it |
| domains | TEXT | JSON array |
| status | TEXT | `queued` → `running` → `success`/`partial`/`failed` |
| persisted_count | INTEGER | articles written to both stores |
| duplicate_count | INTEGER | articles skipped by dedup |
| error_log | TEXT | JSON array of `{domain, url, error}` dicts |
| started_at | DATETIME | |
| finished_at | DATETIME | |

---

## 10. End-to-End Request Flows

### Flow A — Triggering a Refresh

```
Client                FastAPI              Background             Qdrant / SQLite
  │                      │                    │                        │
  │  POST /refresh        │                   │                        │
  │──────────────────────>│                   │                        │
  │                       │ create PipelineRun│                        │
  │                       │ status=running    │                        │
  │                       │──────────────────>│ add_task(run_pipeline) │
  │  {run_id, status}     │                   │                        │
  │<──────────────────────│                   │                        │
  │                       │                   │                        │
  │  GET /status/{run_id} │                   │  [pipeline running...] │
  │──────────────────────>│                   │                        │
  │  {status: running}    │                   │                        │
  │<──────────────────────│                   │                        │
  │                       │                   │                        │
  │                       │                   │  all agents done       │
  │                       │                   │  aggregator writes     │
  │                       │                   │─────────────────────── │
  │  GET /status/{run_id} │                   │                        │
  │──────────────────────>│                   │                        │
  │  {status: success,    │                   │                        │
  │   persisted: 41}      │                   │                        │
  │<──────────────────────│                   │                        │
```

### Flow B — Reading the Feed

```
Client                FastAPI              Qdrant              SQLite
  │                      │                   │                    │
  │  GET /feed?domain=   │                   │                    │
  │  finance&limit=10    │                   │                    │
  │──────────────────────>│                   │                    │
  │                       │ get_by_domain()   │                    │
  │                       │──────────────────>│                    │
  │                       │  10 Records       │                    │
  │                       │<──────────────────│                    │
  │                       │ sqlite_id in      │                    │
  │                       │ payload? Yes → use│                    │
  │                       │ No → bulk lookup  │                    │
  │                       │──────────────────────────────────────>│
  │                       │  {qdrant_id: id}  │                    │
  │                       │<──────────────────────────────────────│
  │                       │ sort by fetched_at desc               │
  │  [{id, title,         │                   │                    │
  │    summary, tags}]    │                   │                    │
  │<──────────────────────│                   │                    │
```

### Flow C — Quiz Generate + Submit

```
Client                FastAPI              SQLite              Groq
  │                      │                   │                    │
  │  POST /quiz/generate  │                   │                    │
  │  {article_id: 7}      │                   │                    │
  │──────────────────────>│                   │                    │
  │                       │ get_article(7)    │                    │
  │                       │──────────────────>│                    │
  │                       │  Article(summary) │                    │
  │                       │<──────────────────│                    │
  │                       │ generate_quiz()   │                    │
  │                       │──────────────────────────────────────>│
  │                       │  3 MCQs (JSON)    │                    │
  │                       │<──────────────────────────────────────│
  │                       │ create_quiz_session()                 │
  │                       │ (answers stored server-side)          │
  │                       │──────────────────>│                    │
  │  {session_id, Qs      │                   │                    │
  │   without answers}    │                   │                    │
  │<──────────────────────│                   │                    │
  │                       │                   │                    │
  │  POST /quiz/submit    │                   │                    │
  │  {session_id,         │                   │                    │
  │   answers: {0:B...}}  │                   │                    │
  │──────────────────────>│                   │                    │
  │                       │ submit_quiz_session()                 │
  │                       │ compare answers vs stored correct     │
  │                       │──────────────────>│                    │
  │  {score: 0.667,       │                   │                    │
  │   breakdown: [...]}   │                   │                    │
  │<──────────────────────│                   │                    │
```

---

## 11. Rate Limit Strategy

Groq free tier limits: ~30 requests/minute, ~14,400 tokens/minute.

A naive parallel run across 7 agents × 6 articles each = 42 simultaneous Groq calls → instant and sustained 429 storm. The pipeline evolved through several mitigations:

| Mitigation | Where | Effect |
|-----------|-------|--------|
| All 7 agents fanned out concurrently | `graph.py` | Each domain runs on Python's default thread-pool executor via `run_in_executor` + `asyncio.gather` — not sequential |
| Semaphore(2) | `groq_client.py` | Hard cap of 2 concurrent Groq calls across all 7 agent threads — this is what actually keeps the pipeline under Groq's rate limit |
| Exponential backoff | `groq_client.py` | 429s → wait 8s, 16s, 32s, 64s before giving up |
| llama-3.3-70b-versatile | `config.py` | Default model; switch to 8b-instant via `.env` for higher quota |
| articles_per_source=5 | `config.py` | Tunable; reduce to 3 to cut Groq calls |
| tavily_queries_per_agent=2 | `config.py` | Use top 2 queries only (not all 5 hardcoded ones) |

Agent fan-out is 7-wide (all domains start at once); LLM-call concurrency is capped at 2-wide by the semaphore. Tavily/NewsAPI I/O isn't gated at all — only actual Groq calls queue on the semaphore.