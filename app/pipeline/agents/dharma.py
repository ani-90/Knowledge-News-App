from app.pipeline.agents.base_agent import BaseAgent


class DharmaAgent(BaseAgent):
    domain = "dharma"
    tavily_queries = [
        "lesser known stories Mahabharata Ramayana characters",
        "mantra meaning Sanskrit explanation significance",
        "Vedanta Advaita philosophy explained simply",
        "Hindu temple history mythology lesser known",
        "Upanishad teachings practical daily life",
    ]
    newsapi_keywords = ["Vedanta Sanskrit philosophy", "Hindu mythology temple"]
