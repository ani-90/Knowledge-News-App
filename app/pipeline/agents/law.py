from app.pipeline.agents.base_agent import BaseAgent


class LawAgent(BaseAgent):
    domain = "law"
    tavily_queries = [
        "Supreme Court India landmark ruling 2025",
        "India consumer rights legal update",
        "cyber law IT Act India latest judgment",
        "POSH workplace harassment India court ruling",
        "tenant landlord rights India legal news",
    ]
    newsapi_keywords = ["Supreme Court India", "Indian law judgment", "consumer rights India"]
