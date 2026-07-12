# Decisions & Tradeoffs

Engineering decisions made while building Rudh Reads, with the reasoning and tradeoffs for each. Every entry here is something I can defend in an interview and point to in the code.

---

## 1. Dual data store: SQLite + Qdrant

**Decision:** Use two databases instead of one.

**Options considered:**
- SQLite only — store everything relationally, skip vectors
- Qdrant only — store everything as vector payloads
- SQLite + Qdrant together

**Chosen:** SQLite + Qdrant together.

**Why:** The two stores solve different problems that neither handles well alone. SQLite owns structured relational data — users, reading history, quiz sessions, pipeline run status — where joins, foreign keys, and aggregation queries matter (`get_user_stats` runs three `GROUP BY` queries across two tables). Qdrant owns vector embeddings for semantic deduplication — catching paraphrased or syndicated duplicates that URL matching alone misses. A single Qdrant store could hold article payloads but would make the stats queries awkward and lose referential integrity. A single SQLite store could store embedding blobs but has no cosine similarity search.

**What was gained:** Each store does exactly what it's best at. The aggregator's 3-pass design (Qdrant dedup → SQLite insert → Qdrant upsert) keeps the two stores in sync without coupling them tightly.

**What was sacrificed:** Operational complexity — two stores to initialise, back up, and keep consistent. If the Qdrant upsert fails after a successful SQLite insert, the article exists in SQLite but has no vector in Qdrant. This is handled gracefully (the aggregator logs a warning and continues) but it's a real consistency gap.

---

## 2. Qdrant local path vs Qdrant Cloud

**Decision:** Support both local file-based Qdrant and Qdrant Cloud via the same config.

**Options considered:**
- Local Qdrant only (embedded, no Docker)
- Qdrant Cloud only
- Dual-mode: local in dev, cloud in prod

**Chosen:** Dual-mode — `QDRANT_URL` and `QDRANT_API_KEY` are optional env vars. If set, the client connects to Qdrant Cloud; otherwise it falls back to a local file path (`./qdrant_data`).

**Why:** Local embedded Qdrant requires zero infrastructure — no Docker, no cloud account — which makes onboarding and local development instant. The Railway deployment uses Qdrant Cloud for persistence across deploys (local file storage doesn't survive Railway restarts).

**What was gained:** The same codebase runs locally with no setup beyond `pip install` and runs in production on Railway without changing a line of code.

**What was sacrificed:** The local path has a hard constraint: `reload=False` is mandatory in `run.py`. Uvicorn's reload mode spawns a second process that tries to open `qdrant_data/` and gets killed by Qdrant's file lock. Forgetting this crashes the server silently on startup.

---

## 3. Embeddings disabled on Railway

**Decision:** Stub out the embedder (`embed()` returns `[]`) on the deployed Railway instance.

**Options considered:**
- Run `sentence-transformers all-MiniLM-L6-v2` in production
- Use a hosted embedding API (OpenAI, Cohere)
- Disable embeddings, fall back to URL-exact dedup

**Chosen:** Disable embeddings on Railway, keep the full stack locally.

**Why:** `sentence-transformers` with `all-MiniLM-L6-v2` loads ~80MB into memory and requires PyTorch. Railway's free tier sits around 512MB RAM. Loading the model on startup consumed enough memory to push the app into OOM territory under normal pipeline load (7 agents + Groq calls + SQLAlchemy). URL-exact deduplication (enforced by the `UNIQUE` constraint on `Article.url`) handles the common case well enough for a personal-use app.

**What was gained:** Stable deployments within Railway's memory envelope.

**What was sacrificed:** Semantic deduplication — two articles covering the same story with different URLs and slightly different wording both get stored. In practice, UTM-param stripping and URL normalisation in `_normalise_url()` catches most syndication duplicates before they reach the dedup stage.

**Next step:** A hosted embedding API (one API call per article, no resident model memory) would restore semantic dedup without the memory cost.

---

## 4. Groq over OpenAI for LLM calls

**Decision:** Use Groq with Llama 3.3 70B Versatile instead of OpenAI GPT.

**Options considered:**
- OpenAI GPT-4o
- Anthropic Claude
- Groq with Llama 3.3 70B

**Chosen:** Groq.

**Why:** The pipeline calls the LLM for every article — summarisation, tag generation, and optionally quiz generation. At 7 agents × 2–5 queries each, a single pipeline run makes 15–35 LLM calls. Groq's inference hardware (LPU) returns responses in 1–3 seconds per call versus 5–15 seconds on OpenAI's API at peak times. For a daily batch pipeline where total runtime matters, this compounds significantly. Groq's free tier also has no per-token cost, which made experimentation frictionless.

**What was gained:** Fast pipeline completion, zero LLM cost during development.

**What was sacrificed:** Groq's rate limits are aggressive — 30 requests/minute on the free tier. With 7 agents running in parallel, hitting the limit on every pipeline run was the first production problem encountered. This led directly to the `Semaphore(2)` and exponential backoff retry.

---

## 5. Concurrency cap via threading.Semaphore(2)

**Decision:** Limit concurrent Groq API calls to 2 across all parallel agents.

**Options considered:**
- No cap — let all 7 agents call Groq freely
- `asyncio.Semaphore` — async semaphore
- `threading.Semaphore` — thread-safe semaphore

**Chosen:** `threading.Semaphore(2)` in `groq_client.py`.

**Why:** The 7 agents run in a thread pool via `run_in_executor` — they are synchronous functions on OS threads, not async coroutines. An `asyncio.Semaphore` only works within a single event loop and would not protect across threads. `threading.Semaphore` is thread-safe by design. The cap of 2 was arrived at empirically: Groq's free tier allows ~30 requests/minute, each agent makes 3–5 calls, and 7 agents running freely hit 429 errors on every pipeline run. Capping at 2 concurrent callers keeps the request rate comfortably under the limit.

**What was gained:** Zero 429 errors under normal pipeline load.

**What was sacrificed:** Pipeline throughput — agents that finish their fetch phase wait for the semaphore before they can summarise. Total pipeline runtime is longer than if all agents could call Groq simultaneously.

---

## 6. Exponential backoff on Groq rate limit errors

**Decision:** Retry Groq calls with exponential backoff: 8s → 16s → 32s → 64s, max 4 attempts.

**Options considered:**
- Fail fast on 429, skip the article
- Fixed delay retry (e.g. 5s between each attempt)
- Exponential backoff

**Chosen:** Exponential backoff starting at 8 seconds.

**Why:** Groq's 429 errors occur when the rate limit window is exhausted. A fixed short delay (1–2s) retries before the window resets and hits 429 again immediately. Exponential backoff gives the window time to reset — an 8-second base covers Groq's typical 1-minute rolling window after 2–3 retries. Starting at 8s rather than 1s avoids wasting retries on delays too short to help.

**What was gained:** Articles that hit a rate limit spike are retried successfully rather than silently dropped.

**What was sacrificed:** A single article that exhausts all 4 retries adds up to 120 seconds of blocking time on that thread. In practice this is rare; the semaphore prevents the burst that triggers it.

---

## 7. LLM-generated Tavily queries with hardcoded fallback

**Decision:** Generate Tavily search queries dynamically using Groq, fall back to hardcoded queries if generation fails.

**Options considered:**
- Hardcoded queries only — deterministic, always available
- LLM-generated queries only — fresh, diverse, but fragile
- LLM-generated with hardcoded fallback

**Chosen:** LLM-generated with hardcoded fallback.

**Why:** Hardcoded queries go stale. "RBI monetary policy repo rate India 2025" is relevant in early 2025 but not in late 2026. LLM-generated queries can reflect what's currently newsworthy in a domain — asking the model to generate "diverse, specific search queries for Finance news in India" produces queries that cover different angles (policy, data, people, events) rather than repeating the same fixed keywords. The fallback protects against the Groq call itself failing (network error, rate limit during query generation).

**What was gained:** More diverse article coverage that adapts over time without code changes.

**What was sacrificed:** An extra Groq call per agent per pipeline run (7 additional calls). This adds to rate limit pressure — one reason the semaphore cap matters.

---

## 8. LangGraph StateGraph over plain asyncio

**Decision:** Use LangGraph to wire the pipeline instead of raw `asyncio.gather`.

**Options considered:**
- Plain `asyncio.gather` — minimal, no dependency
- LangGraph `StateGraph` — explicit nodes, typed state, graph execution

**Chosen:** LangGraph `StateGraph`.

**Why:** The pipeline has a typed shared state (`PipelineState`) that parallel branches write to and the aggregator reads from. LangGraph handles the state merging contract explicitly — `raw_articles: Annotated[List[ArticleData], operator.add]` means parallel agent results are automatically concatenated when branches complete, without manual coordination code. The node boundary between `run_all_agents` and `aggregator` also makes each stage independently testable and replaceable.

**What was gained:** Clean state management, explicit graph topology, easier to extend (adding a new node or a conditional branch is a one-line graph edit).

**What was sacrificed:** A dependency on LangGraph for what is ultimately a two-node linear pipeline. For this specific use case, `asyncio.gather` would have been simpler. LangGraph's value pays off more as the graph grows.

---

## 9. Agents run in thread pool, not native async

**Decision:** Run domain agents via `loop.run_in_executor(None, run_single, domain)` rather than making them async functions.

**Options considered:**
- Make agents `async def` and use `asyncio.gather`
- Keep agents synchronous, run in thread pool executor

**Chosen:** Thread pool executor.

**Why:** Each agent calls multiple synchronous blocking libraries — `trafilatura.fetch_url()`, the `groq` SDK, and `newsapi_client`. These do not have native async implementations. Wrapping them in `asyncio.run_in_executor` pushes them onto OS threads where blocking I/O doesn't stall the event loop, achieving true parallelism across agents without rewriting every library call.

**What was gained:** Real parallel execution across 7 agents with no changes to the underlying service libraries.

**What was sacrificed:** Thread overhead and the complexity of mixing `asyncio` with `threading.Semaphore` (which was required precisely because the Groq calls happen on threads, not coroutines).

---

## 10. 4-layer deduplication chain

**Decision:** Apply four distinct deduplication checks before storing an article.

**The four layers (in order):**
1. UTM parameter stripping in `_normalise_url()` — removes tracking params (`utm_source`, `fbclid`, etc.) before comparison
2. `seen_urls` set in `_fetch_all()` — in-memory dedup within a single agent's fetch session
3. Semantic dedup via Qdrant at cosine similarity ≥ 0.85 — catches paraphrased/syndicated duplicates (when embeddings are enabled)
4. URL-exact dedup via SQLite `UNIQUE` constraint on `Article.url` — final hard dedup at insert time

**Why so many layers?** Each layer catches a different class of duplicate. UTM stripping catches the same article shared via different tracking links. The `seen_urls` set stops the same URL appearing twice within one agent's Tavily results. Semantic dedup catches "same story, different outlet" syndication. SQLite's unique constraint is the safety net — a race condition between two parallel agents trying to insert the same URL is caught here, rolled back cleanly, and the session continues.

**What was gained:** Near-zero duplicate articles in the feed despite fetching from two sources (Tavily + NewsAPI) across 7 parallel agents.

**What was sacrificed:** Complexity — the aggregator's `bulk_insert_articles` commits one article at a time inside a loop specifically to handle the parallel-agent race condition gracefully. A bulk commit would be faster but would fail the entire batch if one URL collided.

---

## 11. SQLite locally, PostgreSQL on Railway

**Decision:** Use the same SQLAlchemy codebase for both SQLite (local dev) and PostgreSQL (Railway production).

**Options considered:**
- SQLite everywhere — simple, no config
- PostgreSQL everywhere — production-grade, requires Docker locally
- SQLAlchemy with `DATABASE_URL` switching

**Chosen:** `DATABASE_URL` switching — SQLite when the URL starts with `sqlite://`, PostgreSQL when Railway injects its `DATABASE_URL`.

**Why:** SQLite requires zero setup for local development. PostgreSQL on Railway is free with the starter plan and survives deploys (unlike SQLite on Railway's ephemeral filesystem). SQLAlchemy's abstraction means the ORM models, queries, and session management are identical in both environments — `sqlite.py` is the only file that knows which engine is in use.

**What was gained:** Instant local setup (`python run.py` with no Docker) and production-grade persistence on Railway with no code changes.

**What was sacrificed:** SQLite and PostgreSQL have subtle dialect differences. `check_same_thread: False` is SQLite-specific and is conditionally added only when the URL starts with `sqlite`. Any raw SQL would need to be dialect-aware — avoided by keeping everything in SQLAlchemy ORM.

---

## 12. On-demand summarisation, not pipeline-time

**Decision:** Summarise articles when requested via the `/summarize` endpoint, not during the pipeline run.

**Options considered:**
- Summarise every article during the pipeline run (eager)
- Summarise on first request, cache in SQLite (lazy)

**Chosen:** Lazy — summarise on demand, cache the result.

**Why:** The pipeline already makes heavy use of Groq for query generation. Adding per-article summarisation during the run would multiply Groq calls by the number of articles fetched (potentially 50–70 per run), making rate limit exhaustion near-certain and extending pipeline runtime significantly. Articles that are never read would be summarised unnecessarily.

**What was gained:** Pipeline completes faster, Groq usage is proportional to actual reading activity.

**What was sacrificed:** The first user to open an article experiences latency while the summary is generated (typically 2–4 seconds). The quiz feature also depends on the summary existing — it generates one silently if missing, which adds a hidden Groq call to the quiz flow.

---

## Lessons learned

**Rate limits compound faster than expected.** 7 agents × 5 queries × 1 LLM call each = 35 Groq calls before a single article is summarised. This hit the free tier limit on the first real pipeline run. The semaphore and backoff were added reactively.

**Two sources create more duplicates than expected.** Tavily and NewsAPI frequently surface the same article from different URLs (one with tracking params, one without). The UTM-stripping layer was added after observing the duplicate count in pipeline run logs.

**Lazy summarisation has a hidden cost.** The quiz endpoint generating a summary silently when one doesn't exist means a single quiz request can trigger two Groq calls (summary + questions). This wasn't obvious until tracing the call graph.

**Railway memory limits are a hard constraint, not a soft one.** The embedder was working locally and disabled only after the first Railway deploy OOM'd mid-pipeline. Memory profiling should have been part of the pre-deploy checklist.