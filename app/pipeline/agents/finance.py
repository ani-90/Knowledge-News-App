from app.pipeline.agents.base_agent import BaseAgent


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
