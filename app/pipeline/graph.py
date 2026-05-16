import logging
from langgraph.graph import StateGraph, START, END

from app.pipeline.state import PipelineState
from app.pipeline.aggregator import aggregator_node
from app.pipeline.agents.finance import FinanceAgent
from app.pipeline.agents.politics import PoliticsAgent
from app.pipeline.agents.ai_tech import AiTechAgent
from app.pipeline.agents.law import LawAgent
from app.pipeline.agents.health import HealthAgent
from app.pipeline.agents.fashion import FashionAgent
from app.pipeline.agents.dharma import DharmaAgent

logger = logging.getLogger(__name__)

_AGENT_MAP = {
    "finance": FinanceAgent(),
    "politics": PoliticsAgent(),
    "ai_tech": AiTechAgent(),
    "law": LawAgent(),
    "health": HealthAgent(),
    "fashion": FashionAgent(),
    "dharma": DharmaAgent(),
}


def run_all_agents_node(state: PipelineState) -> dict:
    """Run each requested domain agent sequentially to stay within Groq rate limits."""
    all_articles = []
    all_errors = []

    for domain in state["domains_requested"]:
        agent = _AGENT_MAP.get(domain)
        if not agent:
            logger.warning("Unknown domain requested: %s", domain)
            continue
        logger.info("Running agent: %s", domain)
        result = agent.run(state)
        all_articles.extend(result.get("raw_articles", []))
        all_errors.extend(result.get("errors", []))
        logger.info("Agent %s done — %d articles, %d errors", domain, len(result.get("raw_articles", [])), len(result.get("errors", [])))

    return {"raw_articles": all_articles, "errors": all_errors}


def _build_graph():
    builder = StateGraph(PipelineState)
    builder.add_node("run_all_agents", run_all_agents_node)
    builder.add_node("aggregator", aggregator_node)
    builder.add_edge(START, "run_all_agents")
    builder.add_edge("run_all_agents", "aggregator")
    builder.add_edge("aggregator", END)
    return builder.compile()


pipeline = _build_graph()


async def run_pipeline(run_id: str, user_id: int, domains: list) -> dict:
    from datetime import datetime, timezone
    initial_state: PipelineState = {
        "user_id": user_id,
        "domains_requested": domains,
        "run_id": run_id,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "raw_articles": [],
        "errors": [],
        "persisted_count": 0,
        "duplicate_count": 0,
        "finished_at": "",
        "status": "running",
    }
    return await pipeline.ainvoke(initial_state)
