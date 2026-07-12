# Knowledge News App

Personal AI-powered daily reading platform for educated Indians. Fetches, summarises, and quizzes across 7 knowledge domains.

## Stack

| Layer | Technology |
|-------|-----------|
| Backend framework | FastAPI (no reload mode — see constraints) |
| Agent pipeline | LangGraph 0.2.x — 2-node `StateGraph` (`run_all_agents → aggregator`); the 7 domain agents run **in parallel** inside `run_all_agents_node` via a thread-pool executor, not via LangGraph `Send()` |
| LLM | Groq API — `llama-3.3-70b-versatile` (NOT Anthropic) |
| Vector store | Qdrant local path-based (`./qdrant_data`) or cloud — wired up but currently inert (see Embeddings below) |
| Relational DB | SQLite locally / Postgres on Railway, via SQLAlchemy |
| Embeddings | **Disabled.** `app/services/embedder.py::embed()` is a stub returning `[]` unconditionally, to stay within Railway's memory limit. No semantic dedup, no RAG/retrieval anywhere in the app currently. |
| Content sources | Tavily Search API (`search_depth="advanced"`, `topic="news"`) + NewsAPI (`get_top_headlines(country="in")`) |
| Frontend | Flutter (Dio REST client, Provider state management, polling — no websockets) |

## Setup (do in this exact order)

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1

# 1. Torch FIRST — must be CPU wheel or it downloads 2.5GB CUDA build
pip install torch --index-url https://download.pytorch.org/whl/cpu

# 2. Everything else
pip install -r requirements.txt

# 3. Create .env from template and fill in your 3 keys
copy .env.example .env
```

## Required env vars (.env)

```
GROQ_API_KEY=      # console.groq.com
TAVILY_API_KEY=    # tavily.com
NEWSAPI_KEY=       # newsapi.org
```

## Run

```powershell
.venv\Scripts\python.exe run.py
# → http://localhost:8000/docs
```

## 7 Knowledge Domains

`finance` · `politics` · `ai_tech` · `law` · `health` · `fashion` · `dharma`

## Key Constraints

**Qdrant single-process lock** — `qdrant_data/` can only be opened by one process at a time. Two consequences:
- `run.py` uses `reload=False` — uvicorn reload mode spawns two processes and will crash on startup
- Never run a standalone Python script that imports `app.db.qdrant` while the server is running; query through the API instead
- In practice this rarely matters right now since Qdrant is never actually written to (embeddings are disabled)

**Torch must be installed before sentence-transformers** — otherwise pip resolves the wrong (CUDA) torch wheel. (Note: the embedder itself is currently stubbed out, so this mainly matters if/when embeddings are re-enabled.)

**Embeddings are disabled** — `embedder.embed()` always returns `[]`. This means:
- `aggregator.py`'s semantic-dedup pass (`search_similar(embedding, threshold=0.85)`) never triggers — the only active deduplication is exact-URL matching in `crud.bulk_insert_articles`
- Qdrant upserts are skipped (gated on `if article.embedding:`)
- There is no retrieval-augmented generation anywhere — `GET /api/feed` and quiz generation read straight from SQLite/Postgres

**Scheduler is not started** — `app/scheduler.py` (APScheduler) exists but is never called from `main.py`'s lifespan. Feed refresh is manual-only via `POST /api/feed/refresh`, gated by a 2-hour cooldown (checked against the last successful `PipelineRun`).

## Project Structure

```
app/
├── config.py               # Pydantic-settings — reads .env
├── main.py                 # FastAPI app; lifespan calls init_db() only (no Qdrant init, no embedder warmup)
├── scheduler.py             # APScheduler cron job — defined but not wired into main.py
├── api/
│   ├── feed.py              # POST /api/feed/refresh, GET /api/feed, GET /api/feed/status/{run_id}, /{id}/summarize, /{id}/read
│   ├── quiz.py               # POST /api/quiz/generate, POST /api/quiz/submit
│   ├── debate.py            # POST /api/debate/message — stateless per-turn, client resends history
│   └── user.py              # POST /api/user, GET /api/user/stats
├── pipeline/
│   ├── state.py             # PipelineState TypedDict + ArticleData dataclass
│   ├── graph.py             # Builds StateGraph(START → run_all_agents → aggregator → END); run_all_agents_node
│   │                         #   fans domain agents out in parallel via asyncio.run_in_executor + gather;
│   │                         #   run_pipeline(run_id, user_id, domains) is the entry point used by feed.py
│   ├── aggregator.py         # SQLite bulk insert (real dedup) + inert semantic/Qdrant dedup passes
│   └── agents/
│       ├── base_agent.py    # Fetch (Tavily + NewsAPI) → quality filter → embed (stub) → return ArticleData list
│       └── [7 domain agents — each defines domain, tavily_queries, newsapi_keywords]
├── services/
│   ├── groq_client.py       # summarize(), generate_quiz(), generate_queries(), debate_reply() — rate-limited via Semaphore(2) + backoff
│   ├── tavily_client.py     # search() wrapper
│   ├── newsapi_client.py    # search() + get_india_headlines() wrappers
│   └── embedder.py          # embed() — STUBBED, always returns []; warmup() is a no-op
├── db/
│   ├── sqlite.py            # Engine, SessionLocal, init_db()
│   ├── models.py            # User, Article, ReadingHistory, QuizSession, PipelineRun
│   ├── qdrant.py            # get_client(), init_collection(), search_similar(), upsert_articles() — mostly unused at runtime
│   └── crud.py              # All DB helpers used by API and pipeline
└── schemas/                 # Pydantic request/response models for each router
```

## Pipeline Flow

```
POST /api/feed/refresh
  → check 2-hour cooldown against last successful PipelineRun; if active, return status="skipped" immediately
  → insert PipelineRun (status=running)
  → BackgroundTasks launches run_pipeline() (same process, after HTTP response is sent)
      → LangGraph: START → run_all_agents_node → aggregator_node → END
          run_all_agents_node runs all 7 domain agents IN PARALLEL (thread-pool executor):
              each agent: Groq generates diverse search queries (fallback to hardcoded list)
              → Tavily search + NewsAPI top-headlines(country=in)
              → dedup by normalized URL (strips UTM params) within the agent's own results
              → quality-filter scraped content
              → compute content hash + embedding (always [] — disabled)
              → summary/tags left EMPTY at this stage (populated lazily later, not in the pipeline)
          aggregator_node:
              semantic dedup via Qdrant cosine similarity (threshold=0.85) — DEAD CODE, never triggers (embedding always falsy)
              SQLite bulk insert — real dedup: per-row exact-URL uniqueness check, per-row commit/rollback
              Qdrant upsert — DEAD CODE, skipped (gated on truthy embedding)
              update PipelineRun (status=success/partial/failed, persisted_count, duplicate_count, error_log)
```

**Why parallel is safe despite Groq's free-tier 30 req/min limit:** a global `threading.Semaphore(2)` in `groq_client.py` caps concurrent Groq calls across all agent threads, and `RateLimitError` triggers exponential backoff (8/16/32/64s) — so parallel agents don't cause a 429 storm.

## Lazy summarization & quiz generation

Summaries are **not** generated during the pipeline run. They're created on first access:
- `GET /api/feed/{article_id}` and `POST /api/quiz/generate` both check `if not article.summary:` and call `groq_client.summarize()` synchronously, persisting the result before continuing.
- `POST /api/quiz/generate`: ensures summary exists → `groq_client.generate_quiz(summary)` (Groq returns 3 MCQs as JSON) → persists a `QuizSession` row → returns questions **without** the answer key.
- `POST /api/quiz/submit`: grades by comparing submitted answers to the stored key, persists score, returns a per-question breakdown with explanations. Blocked (409) if the session was already submitted.

## SQLite Tables

`users` · `articles` · `reading_history` · `quiz_sessions` · `pipeline_runs`

`articles.qdrant_id` is generated and stored on every article regardless of whether a corresponding Qdrant point actually exists (since Qdrant upserts are currently dead code).

## Common Commands

```powershell
# Trigger a full refresh (all 7 domains) — subject to 2-hour cooldown
Invoke-RestMethod -Uri "http://localhost:8000/api/feed/refresh" -Method POST `
  -ContentType "application/json" -Body '{"user_id":1}'

# Check run status
Invoke-RestMethod "http://localhost:8000/api/feed/status/<run_id>"

# Get feed for a domain
Invoke-RestMethod "http://localhost:8000/api/feed?domain=finance&limit=10"

# Generate quiz for article id=1
Invoke-RestMethod -Uri "http://localhost:8000/api/quiz/generate" -Method POST `
  -ContentType "application/json" -Body '{"article_id":1,"user_id":1}'

# Submit answers
Invoke-RestMethod -Uri "http://localhost:8000/api/quiz/submit" -Method POST `
  -ContentType "application/json" -Body '{"session_id":1,"answers":{"0":"B","1":"A","2":"C"}}'

# Debate an article
Invoke-RestMethod -Uri "http://localhost:8000/api/debate/message" -Method POST `
  -ContentType "application/json" -Body '{"article_id":1,"history":[],"message":"Why does this matter?"}'
```

## What's Not Built Yet

- Daily auto-refresh scheduler (code exists in `app/scheduler.py` but is not wired into `main.py` startup)
- Real embeddings / semantic dedup / RAG (currently fully stubbed out to fit Railway's memory limit)
- Full-article scraping fallback for thin NewsAPI content (partial: `GET /api/feed/{id}` re-scrapes on demand if stored content is too short or low quality)
- Authentication
