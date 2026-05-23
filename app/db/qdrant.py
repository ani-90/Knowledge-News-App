from typing import List, Optional

from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance,
    FieldCondition,
    Filter,
    MatchValue,
    PointStruct,
    VectorParams,
)

from app.config import settings

_client: Optional[QdrantClient] = None


def get_client() -> QdrantClient:
    global _client
    if _client is None:
        if settings.qdrant_url:
            # Qdrant Cloud
            _client = QdrantClient(url=settings.qdrant_url, api_key=settings.qdrant_api_key)
        else:
            # Local fallback for dev
            _client = QdrantClient(path=settings.qdrant_path)
    return _client


def init_collection() -> None:
    client = get_client()
    if not client.collection_exists(settings.qdrant_collection):
        client.create_collection(
            collection_name=settings.qdrant_collection,
            vectors_config=VectorParams(size=384, distance=Distance.COSINE),
        )


def search_similar(vector: List[float], threshold: float = None, limit: int = 1):
    if threshold is None:
        threshold = settings.similarity_threshold
    client = get_client()
    return client.search(
        collection_name=settings.qdrant_collection,
        query_vector=vector,
        limit=limit,
        score_threshold=threshold,
    )


def upsert_articles(points: List[dict]) -> int:
    """Each point: {qdrant_id, vector, title, url, summary, domain, tags, source, fetched_at, sqlite_id}"""
    client = get_client()
    structs = [
        PointStruct(
            id=p["qdrant_id"],
            vector=p["vector"],
            payload={k: v for k, v in p.items() if k != "vector"},
        )
        for p in points
    ]
    if structs:
        client.upsert(collection_name=settings.qdrant_collection, points=structs)
    return len(structs)


def get_by_domain(domain: str, limit: int = 20) -> list:
    client = get_client()
    results = client.scroll(
        collection_name=settings.qdrant_collection,
        scroll_filter=Filter(
            must=[FieldCondition(key="domain", match=MatchValue(value=domain))]
        ),
        limit=limit,
        with_payload=True,
        with_vectors=False,
    )
    return results[0]


def get_all_recent(limit: int = 100) -> list:
    client = get_client()
    results = client.scroll(
        collection_name=settings.qdrant_collection,
        limit=limit,
        with_payload=True,
        with_vectors=False,
    )
    return results[0]
