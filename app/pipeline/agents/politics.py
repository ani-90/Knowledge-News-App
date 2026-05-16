from app.pipeline.agents.base_agent import BaseAgent


class PoliticsAgent(BaseAgent):
    domain = "politics"
    tavily_queries = [
        "India domestic politics news today parliament",
        "India US relations bilateral diplomacy 2025",
        "India China LAC border relations latest",
        "Indian election politics state assembly",
        "global geopolitics UN security council India",
    ]
    newsapi_keywords = ["India politics", "Indian parliament", "India diplomacy"]
