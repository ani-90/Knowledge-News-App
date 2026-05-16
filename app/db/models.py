from datetime import datetime
from sqlalchemy import (
    Column, Integer, String, Float, DateTime, ForeignKey, Text
)
from sqlalchemy.orm import relationship
from app.db.sqlite import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String, unique=True, nullable=False)
    display_name = Column(String)
    preferences = Column(Text, default="{}")  # JSON: {domains, quiz_difficulty}
    created_at = Column(DateTime, default=datetime.utcnow)

    reading_history = relationship("ReadingHistory", back_populates="user")
    quiz_sessions = relationship("QuizSession", back_populates="user")


class Article(Base):
    __tablename__ = "articles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    qdrant_id = Column(String, unique=True, nullable=False)
    url = Column(String, unique=True, nullable=False)
    title = Column(String, nullable=False)
    summary = Column(Text, nullable=False)
    domain = Column(String, nullable=False)
    source = Column(String, nullable=False)  # "tavily" | "newsapi"
    tags = Column(Text, default="[]")        # JSON array
    raw_content = Column(Text)
    fetched_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)

    reading_history = relationship("ReadingHistory", back_populates="article")
    quiz_sessions = relationship("QuizSession", back_populates="article")


class ReadingHistory(Base):
    __tablename__ = "reading_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    article_id = Column(Integer, ForeignKey("articles.id"), nullable=False)
    read_at = Column(DateTime, default=datetime.utcnow)
    read_duration_seconds = Column(Integer)

    user = relationship("User", back_populates="reading_history")
    article = relationship("Article", back_populates="reading_history")


class QuizSession(Base):
    __tablename__ = "quiz_sessions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    article_id = Column(Integer, ForeignKey("articles.id"), nullable=False)
    domain = Column(String, nullable=False)
    questions_json = Column(Text, nullable=False)  # full Q&A JSON blob
    user_answers = Column(Text)                    # JSON: {"0":"B","1":"A",...}
    score = Column(Float)
    total_questions = Column(Integer)
    correct_count = Column(Integer)
    submitted_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="quiz_sessions")
    article = relationship("Article", back_populates="quiz_sessions")


class PipelineRun(Base):
    __tablename__ = "pipeline_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    run_id = Column(String, unique=True, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"))
    domains = Column(Text, default="[]")    # JSON array
    status = Column(String, default="queued")  # queued|running|success|partial|failed
    persisted_count = Column(Integer, default=0)
    duplicate_count = Column(Integer, default=0)
    error_log = Column(Text, default="[]")  # JSON array of error dicts
    started_at = Column(DateTime)
    finished_at = Column(DateTime)
