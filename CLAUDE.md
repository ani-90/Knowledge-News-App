# Knowledge News App

Personal AI-powered daily reading platform for educated Indians. Fetches, summarises, and quizzes across 7 knowledge domains.

## Stack

| Layer | Technology |
|-------|-----------|
| Backend framework | FastAPI (no reload mode — see constraints) |
| Agent pipeline | LangGraph 0.2.x — StateGraph with parallel Send() fan-out |
| LLM | Groq API — `llama-3.3-70b-versatile` (NOT Anthropic) |
| Vector store | Qdrant local path-based (`./qdrant_data`) — no Docker |
| Relational DB | SQLite via SQLAlchemy |
| Embeddings | `all-MiniLM-L6-v2` via sentence-transformers (local, CPU) |
| Content sources | Tavily Search API + NewsAPI |

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

**Torch must be installed before sentence-transformers** — otherwise pip resolves the wrong (CUDA) torch wheel.

**Embedding model downloads on first run** — `all-MiniLM-L6-v2` (~80MB) downloads to `~/.cache/huggingface` on first startup. Subsequent starts are instant.

## Project Structure

```
app/
├── config.py               # Pydantic-settings — reads .env
├── main.py                 # FastAPI app, startup hooks (init DB, Qdrant, embedder warmup)
├── api/
│   ├── feed.py             # POST /api/feed/refresh, GET /api/feed, GET /api/feed/status/{run_id}
│   ├── quiz.py             # POST /api/quiz/generate, POST /api/quiz/submit
│   └── user.py             # GET /api/user/stats
├── pipeline/
│   ├── state.py            # PipelineState TypedDict + ArticleData dataclass
│   ├── graph.py            # StateGraph — fans out from START via Send(), aggregates at end
│   ├── orchestrator.py     # route_to_agents() — returns List[Send], one per domain
│   ├── aggregator.py       # Qdrant dedup + upsert + SQLite bulk insert
│   └── agents/
│       ├── base_agent.py   # Fetch → summarise (Groq) → embed → return ArticleData list
│       └── [7 domain agents — each defines tavily_queries + newsapi_keywords]
├── services/
│   ├── groq_client.py      # summarize() + generate_quiz() — returns JSON, temp=0.3
│   ├── tavily_client.py    # search() wrapper
│   ├── newsapi_client.py   # get_india_headlines() wrapper
│   └── embedder.py         # embed() — singleton model, call warmup() at startup
├── db/
│   ├── sqlite.py           # Engine, SessionLocal, init_db()
│   ├── models.py           # User, Article, ReadingHistory, QuizSession, PipelineRun
│   ├── qdrant.py           # get_client(), init_collection(), search_similar(), upsert_articles()
│   └── crud.py             # All DB helpers used by API and pipeline
└── schemas/                # Pydantic request/response models for each router
```

## Pipeline Flow

```
POST /api/feed/refresh
  → insert PipelineRun (status=running)
  → BackgroundTasks launches run_pipeline()
      → LangGraph: START → run_all_agents_node → aggregator → END
          run_all_agents_node loops SEQUENTIALLY through each domain:
              Tavily (top 2 queries, 3 results each) + NewsAPI (1 keyword)
              → dedup by URL → scrape short content → Groq summarise → embed
              → 2s delay between each Groq call (rate limit protection)
          aggregator:
              Qdrant similarity check (cosine > 0.95 = duplicate, skip)
              upsert new vectors to Qdrant
              bulk insert to SQLite
              update PipelineRun (status=success/partial/failed)
```

**Why sequential not parallel:** Groq free tier is 30 req/min. 7 parallel agents each
summarising 6 articles = 42 simultaneous calls → instant 429 storm. Sequential
execution stays within the limit naturally.

## SQLite Tables

`users` · `articles` · `reading_history` · `quiz_sessions` · `pipeline_runs`

`articles.qdrant_id` links every SQLite row to its Qdrant point.

## Common Commands

```powershell
# Trigger a full refresh (all 7 domains)
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
```

## What's Not Built Yet

- Flutter frontend
- Daily auto-refresh scheduler (APScheduler)
- Full-article scraping fallback (NewsAPI free tier truncates content at 200 chars)
- Authentication
