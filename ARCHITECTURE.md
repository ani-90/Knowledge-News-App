# Knowledge News App — Backend Architecture

Personal AI-powered daily reading platform. Fetches, summarises, and quizzes across 7 knowledge domains for educated Indian readers.

---

## Table of Contents

1. [High-Level Overview](#1-high-level-overview)
2. [Directory Map](#2-directory-map)
3. [Startup Sequence](#3-startup-sequence)
4. [API Layer](#4-api-layer)
5. [Pipeline — How Articles Are Fetched](#5-pipeline--how-articles-are-fetched)
6. [Domain Agents](#6-domain-agents)
7. [Services](#7-services)
8. [Data Stores](#8-data-stores)
9. [Database Schema](#9-database-schema)
10. [End-to-End Request Flows](#10-end-to-end-request-flows)
11. [Rate Limit Strategy](#11-rate-limit-strategy)
12. [Key Design Decisions](#12-key-design-decisions)

---

## 1. High-Level Overview

```
Flutter App (future)
      │
      │  HTTP / JSON
      ▼
┌─────────────────────────────────────────┐
│           FastAPI  (port 8000)          │
│                                         │
│  /api/feed   /api/quiz   /api/user      │
└────────────┬────────────────────────────┘
             │ BackgroundTask
             ▼
┌─────────────────────────────────────────┐
│         LangGraph Pipeline              │
│                                         │
│  run_all_agents_node  →  aggregator     │
│  (sequential, one domain at a time)     │
└────────┬────────────────────┬───────────┘
         │                    │
         ▼                    ▼
  Tavily + NewsAPI       Groq LLM
  (fetch raw content)   (summarise + quiz)
         │
         ▼
  sentence-transformers
  (embed summaries)
         │
         ▼
┌────────────────┐   ┌─────────────────┐
│  Qdrant (local)│   │  SQLite          │
│  vector store  │   │  relational DB   │
│  dedup + search│   │  articles, users │
└────────────────┘   └─────────────────┘
```

---

## 2. Directory Map

```
app/
├── config.py               Pydantic-settings — reads .env, exposes typed settings
├── main.py                 FastAPI app factory; lifespan hooks; router registration
├── scheduler.py            APScheduler daily cron (07:00) — fires run_pipeline()
│
├── api/
│   ├── feed.py             POST /api/feed/refresh, GET /api/feed, GET /api/feed/status/{id}
│   │                       POST /api/feed/{article_id}/read
│   ├── quiz.py             POST /api/quiz/generate, POST /api/quiz/submit
│   └── user.py             POST /api/user, GET /api/user/stats
│
├── pipeline/
│   ├── state.py            PipelineState TypedDict + ArticleData dataclass
│   ├── graph.py            StateGraph wiring + run_pipeline() async entry point
│   ├── aggregator.py       Qdrant dedup → upsert → SQLite bulk insert
│   └── agents/
│       ├── base_agent.py   Fetch → scrape → summarise → embed (shared logic)
│       ├── finance.py      RBI, SEBI, ITR, EPF queries
│       ├── politics.py     India domestic + geopolitical + global
│       ├── ai_tech.py      LLM releases, AI tools, engineering blogs
│       ├── law.py          Supreme Court, consumer rights, cyber law
│       ├── health.py       Evidence-based fitness and nutrition
│       ├── fashion.py      Indian context dressing guides
│       └── dharma.py       Vedanta, epics, mantras, festival meaning
│
├── services/
│   ├── groq_client.py      Groq API wrapper — summarize() + generate_quiz()
│   ├── tavily_client.py    Tavily Search API wrapper — search()
│   ├── newsapi_client.py   NewsAPI wrapper — get_india_headlines()
│   ├── embedder.py         sentence-transformers singleton — embed() + warmup()
│   └── scraper.py          httpx fallback scraper for short content
│
├── db/
│   ├── sqlite.py           SQLAlchemy engine, SessionLocal, init_db()
│   ├── models.py           ORM models: User, Article, ReadingHistory, QuizSession, PipelineRun
│   ├── qdrant.py           QdrantClient wrapper — init, search, upsert, scroll
│   └── crud.py             All DB helper functions used by API and pipeline
│
└── schemas/
    ├── feed.py             FeedRefreshRequest, ArticleResponse, FeedResponse
    ├── quiz.py             QuizGenerateRequest/Response, QuizSubmitRequest/Response
    └── user.py             UserStatsResponse
```

---

## 3. Startup Sequence

When `run.py` launches uvicorn, the FastAPI lifespan hook fires in this order:

```
1. init_db()          — create SQLite tables if they don't exist (SQLAlchemy)
2. init_collection()  — create Qdrant "articles" collection if it doesn't exist
3. warmup()           — load all-MiniLM-L6-v2 (~80MB) into memory; first run downloads it
4. start_scheduler()  — register daily 07:00 cron job with APScheduler
```

All four are fast on subsequent starts (model is cached at `~/.cache/huggingface`). The server is ready to accept requests immediately after.

**Critical constraint:** `reload=False` is mandatory in `run.py`. Uvicorn's reload mode spawns a second process — both processes try to open `qdrant_data/` and the second one is killed by Qdrant's file lock.

---

## 4. API Layer

### `POST /api/feed/refresh`

Triggers an article pipeline run in the background. Returns immediately with a `run_id`.

```
Request:  {"user_id": 1, "domains": ["finance", "ai_tech"]}
          (domains defaults to all 7 if omitted)

Response: {"run_id": "<uuid>", "status": "running", "domains": [...]}
```

Internally: creates a `PipelineRun` row in SQLite, then hands off to `BackgroundTasks`. The caller polls `GET /api/feed/status/{run_id}` to track progress.

### `GET /api/feed/status/{run_id}`

Returns current state of a pipeline run.

```
Response: {
  "run_id": "...",
  "status": "success",          // queued | running | success | partial | failed
  "persisted_count": 41,
  "duplicate_count": 1,
  "started_at": "...",
  "finished_at": "...",
  "errors": []
}
```

### `GET /api/feed`

Returns articles from Qdrant, optionally filtered by domain.

```
Query params: ?domain=finance&limit=20

Response: {
  "domain": "finance",
  "articles": [
    {
      "id": 7,               // SQLite article id (needed for quiz generation)
      "qdrant_id": "...",
      "title": "...",
      "url": "...",
      "summary": "...",
      "domain": "finance",
      "source": "tavily",
      "tags": ["SEBI", "ETFs"],
      "fetched_at": "..."
    }
  ],
  "total": 10
}
```

Articles are sorted newest-first. The `id` field is the SQLite primary key — pass it to `/api/quiz/generate`.

### `POST /api/feed/{article_id}/read`

Marks an article as read for a user. Used to build reading history and stats.

```
Query params: ?user_id=1&duration_seconds=120
```

### `POST /api/quiz/generate`

Asks Groq to generate 3 MCQs from an article's stored summary.

```
Request:  {"article_id": 7, "user_id": 1}

Response: {
  "session_id": 1,
  "article_id": 7,
  "domain": "finance",
  "questions": [
    {
      "question": "What is the main objective...",
      "options": {"A": "...", "B": "...", "C": "...", "D": "..."},
      "explanation": "..."
    }
  ]
}
```

Note: correct answers are NOT returned here — they are stored server-side in `quiz_sessions.questions_json` and only revealed after submission.

### `POST /api/quiz/submit`

Scores a user's answers and returns per-question breakdown.

```
Request:  {"session_id": 1, "answers": {"0": "B", "1": "A", "2": "C"}}

Response: {
  "session_id": 1,
  "score": 0.667,
  "correct_count": 2,
  "total_questions": 3,
  "breakdown": [
    {"question": "...", "your_answer": "B", "correct_answer": "B", "is_correct": true, "explanation": "..."},
    ...
  ]
}
```

### `POST /api/user`

Creates a new user.

```
Request:  {"display_name": "Anirudh", "email": "user@example.com"}
Response: {"id": 1, "display_name": "Anirudh", "email": "..."}
```

### `GET /api/user/stats`

Aggregated reading and quiz stats per user.

```
Query params: ?user_id=1

Response: {
  "user_id": 1,
  "total_articles_read": 12,
  "total_quizzes_taken": 4,
  "average_quiz_score": 0.75,
  "scores_by_domain": {"finance": 0.833, "ai_tech": 0.667}
}
```

---

## 5. Pipeline — How Articles Are Fetched

The pipeline is a LangGraph `StateGraph` with two nodes:

```
START → run_all_agents_node → aggregator → END
```

### State (`app/pipeline/state.py`)

```python
class ArticleData:
    # Populated by fetch
    title, url, raw_content, domain, source, fetched_at, content_hash
    # Populated by agent (Groq + embedder)
    summary, tags, embedding, qdrant_id

class PipelineState(TypedDict):
    user_id: int
    domains_requested: List[str]
    run_id: str
    raw_articles: Annotated[List[ArticleData], operator.add]   # merged across agents
    errors: Annotated[List[dict], operator.add]
    persisted_count: int
    duplicate_count: int
    status: str
```

### `run_all_agents_node` (`app/pipeline/graph.py`)

Loops through each requested domain sequentially, calls `agent.run(state)`, and accumulates results:

```
for domain in ["finance", "politics", "ai_tech", "law", "health", "fashion", "dharma"]:
    result = FinanceAgent().run(state)     # blocks until done
    accumulate raw_articles + errors
```

Sequential is intentional — see [Rate Limit Strategy](#11-rate-limit-strategy).

### `aggregator_node` (`app/pipeline/aggregator.py`)

Runs after all agents complete. Deduplicates, stores, and updates the run record:

```
for each article with an embedding:
    1. search_similar(embedding, threshold=0.95)
       → if cosine similarity > 0.95 with any existing point: skip (duplicate)
    2. assign qdrant_id (UUID4)
    3. collect into sqlite_records + qdrant_points

bulk_insert_articles(sqlite_records)          → get back SQLite ids
add sqlite_id to each qdrant_point payload
upsert_articles(qdrant_points)                → upsert into Qdrant

update PipelineRun(status, persisted_count, duplicate_count, finished_at)
```

The SQLite insert happens before the Qdrant upsert so the `sqlite_id` can be embedded in the Qdrant payload. This lets the feed endpoint resolve `id` directly from the Qdrant payload without a secondary database roundtrip for new articles.

---

## 6. Domain Agents

Each agent is a subclass of `BaseAgent` that only defines its queries:

```python
class FinanceAgent(BaseAgent):
    domain = "finance"
    tavily_queries = [
        "RBI monetary policy repo rate India 2025",
        "SEBI circular notification India latest",
        "income tax ITR filing update India 2025",
        "EPF NPS EPFO pension update India",
        "Union budget India impact salaried employees",
    ]
    newsapi_keywords = ["RBI India", "SEBI India", "income tax India", "budget India"]
```

All fetch, scrape, summarise, and embed logic lives in `BaseAgent.run()`:

```
_fetch_all():
    for each of top-2 tavily_queries:
        tavily_client.search(query)         → up to 3 results each (6 total)
    for each newsapi_keyword:
        newsapi_client.get_india_headlines() → up to 3 results
    → dedup by URL within this agent

for each raw item:
    time.sleep(2)                           → pace Groq calls
    scraper.enrich_content(url, content)    → fallback scrape if content < 300 chars
    groq_client.summarize(content)          → {"summary": "...", "tags": [...]}
    embedder.embed(title + " " + summary)   → List[float] (384 dims)
    → build ArticleData
```

### The 7 Domains

| Domain | What it covers |
|--------|---------------|
| `finance` | RBI, SEBI, ITR, EPF, Union Budget |
| `politics` | India domestic + India-US/China relations + geopolitics |
| `ai_tech` | LLM releases, AI tools, engineering papers, dev blogs |
| `law` | Supreme Court, consumer rights, cyber law, RTI |
| `health` | Evidence-based fitness, nutrition, Ayurveda |
| `fashion` | Indian context dressing guides, sustainability |
| `dharma` | Vedanta, epics, mantras, festival meanings |

---

## 7. Services

### `groq_client.py`

The only service with rate-limit protection. Two public functions:

- `summarize(raw_content)` → `{"summary": str, "tags": List[str]}`
- `generate_quiz(summary)` → `List[{question, options, answer, explanation}]`

Both call the internal `_call()` function which enforces:

- **Semaphore(2)** — at most 2 concurrent Groq calls at any time
- **Exponential backoff** on `RateLimitError` (429): waits 8s, 16s, 32s, 64s before giving up
- **JSON fence stripping** — Groq sometimes wraps output in ` ```json ``` ` blocks; `_extract_json()` removes them before parsing

Model: `llama-3.1-8b-instant` (higher free-tier token quota than 70b models).  
Temperature: `0.3` (deterministic, factual).  
Content truncated to 4000 chars before sending to stay within token limits.

### `tavily_client.py`

Wraps `TavilyClient.search()`. Sets `include_raw_content=True` to get full article text instead of the default snippet. Returns up to `ARTICLES_PER_SOURCE` (default 3) results per query.

### `newsapi_client.py`

Wraps NewsAPI `/v2/top-headlines`. Filters to `country=in` (India). Returns up to `ARTICLES_PER_SOURCE` results per keyword. Note: NewsAPI free tier truncates content at ~200 characters — the scraper fallback handles this.

### `scraper.py`

httpx-based fallback scraper. Only fires when the content from the API is under 300 characters. Fetches the URL with a 10s timeout, strips HTML tags with regex, and returns cleaned text. Handles 403 (paywalled) and timeouts gracefully by returning whatever was available.

### `embedder.py`

Singleton `SentenceTransformer("all-MiniLM-L6-v2")`. Loaded once at startup via `warmup()`. `embed(text)` returns a 384-dimensional float list. Input is always `title + " " + summary` to capture both topical keywords and narrative content.

---

## 8. Data Stores

### Qdrant (local, path-based)

```python
QdrantClient(path="./qdrant_data")
```

- No Docker, no server process — Qdrant runs as an embedded Rust library inside the Python process.
- Collection `"articles"`: 384-dim vectors, COSINE distance.
- **Single-process lock** — only one Python process can open `qdrant_data/` at a time. This is why `reload=False` is mandatory.

Key operations:
- `search_similar(vector, threshold=0.95)` — cosine similarity dedup check
- `upsert_articles(points)` — insert/overwrite points; point ID = `qdrant_id` (same UUID stored in SQLite)
- `get_by_domain(domain, limit)` — payload filter scroll for feed retrieval
- `get_all_recent(limit)` — unfiltered scroll for cross-domain feed

### SQLite (via SQLAlchemy)

File: `knowledge_news.db` (auto-created).

Used for everything relational: user management, reading history, quiz sessions, pipeline run tracking. Qdrant handles similarity search; SQLite handles everything else.

The `articles.qdrant_id` column is the foreign key between the two stores.

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
| duplicate_count | INTEGER | articles skipped by Qdrant dedup |
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
| Sequential agents | `graph.py` | One domain at a time; natural pacing |
| 2s inter-article delay | `base_agent.py` | ~30 req/min ceiling respected within a domain |
| Semaphore(2) | `groq_client.py` | Hard cap on concurrent calls (belt + suspenders) |
| Exponential backoff | `groq_client.py` | 429s → wait 8s, 16s, 32s, 64s before giving up |
| llama-3.1-8b-instant | `.env` | 3× higher token quota than 70b models on free tier |
| articles_per_source=3 | `config.py` | Fewer articles per query = fewer Groq calls |
| tavily_queries_per_agent=2 | `config.py` | Use top 2 queries only (not all 5) |

Full 7-domain run takes ~8 minutes sequentially. This is acceptable for a background job.

---

## 12. Key Design Decisions

**Why LangGraph instead of plain async?**  
LangGraph gives a clean state machine with typed state passing between nodes. The `Annotated[List, operator.add]` pattern on `raw_articles` merges agent outputs automatically. It also makes the pipeline easy to extend (add a node, add an edge — the graph handles orchestration).

**Why Qdrant for deduplication?**  
URL-based dedup only catches exact reposts. Cosine similarity at 0.95 catches the same story rewritten by different outlets — common in Indian news. Qdrant's local embedded mode means no additional infrastructure.

**Why SQLite for the relational layer?**  
This is a personal app with one user and ~hundreds of articles. SQLite is zero-setup, file-based, and more than fast enough. The Qdrant + SQLite split gives the best of both: vector similarity from Qdrant, relational joins and aggregations from SQLite.

**Why are `id` and `qdrant_id` both exposed in the feed?**  
`qdrant_id` is the Qdrant point UUID — stable identifier for the vector store entry. `id` is the SQLite integer primary key — required by the quiz and read-history endpoints. The feed endpoint resolves `id` from the Qdrant payload (`sqlite_id` field, set since the fix) or via a bulk SQLite fallback for older records.

**Why no authentication?**  
This is a personal tool. `user_id=1` is the default for all endpoints. Auth is listed as a future addition.
