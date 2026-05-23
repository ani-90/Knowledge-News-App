import logging
from contextlib import asynccontextmanager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db.sqlite import init_db
from app.db.qdrant import init_collection
from app.services.embedder import warmup
from app.scheduler import start_scheduler, stop_scheduler
from app.api import feed, quiz, user


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_db()
    init_collection()
    warmup()
    start_scheduler(hour=settings.schedule_hour, minute=settings.schedule_minute)
    yield
    # Shutdown
    stop_scheduler()


app = FastAPI(
    title="Knowledge News API",
    description="Personal AI-powered daily reading platform for informed Indians.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://knowledge-news-app-production.up.railway.app",
        "http://localhost:8000",
        "http://10.0.2.2:8000",  # Android emulator → host localhost
    ],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(feed.router)
app.include_router(quiz.router)
app.include_router(user.router)


@app.get("/health")
def health():
    return {"status": "ok"}
