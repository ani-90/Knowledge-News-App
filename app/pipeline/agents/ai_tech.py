from app.pipeline.agents.base_agent import BaseAgent


class AiTechAgent(BaseAgent):
    domain = "ai_tech"
    tavily_queries = [
        "new LLM model release AI 2025",
        "AI engineering tools practical guide",
        "open source AI tools developers 2025",
        "machine learning tutorial practical how-to",
        "tech startup India AI product launch",
    ]
    newsapi_keywords = ["artificial intelligence LLM", "AI tools developers", "tech India"]
