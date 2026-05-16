from app.pipeline.agents.base_agent import BaseAgent


class HealthAgent(BaseAgent):
    domain = "health"
    tavily_queries = [
        "evidence based fitness protocol strength training 2025",
        "nutrition diet practical guide Indians",
        "mental health anxiety stress management tips",
        "sleep optimization health protocol",
        "India public health update disease prevention",
    ]
    newsapi_keywords = ["fitness health India", "nutrition diet guide", "mental health India"]
