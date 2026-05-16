from app.pipeline.agents.base_agent import BaseAgent


class FashionAgent(BaseAgent):
    domain = "fashion"
    tavily_queries = [
        "Indian men fashion style guide 2025",
        "office wear dressing guide India practical",
        "Indian wedding ethnic wear styling tips",
        "casual dressing Indian context summer monsoon",
        "affordable fashion brands India style",
    ]
    newsapi_keywords = ["India fashion style", "Indian clothing trends"]
