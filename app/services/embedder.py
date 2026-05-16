from typing import List, Optional
from sentence_transformers import SentenceTransformer
from app.config import settings

_model: Optional[SentenceTransformer] = None


def _get_model() -> SentenceTransformer:
    global _model
    if _model is None:
        _model = SentenceTransformer(settings.embedding_model)
    return _model


def embed(text: str) -> List[float]:
    model = _get_model()
    vector = model.encode(text, normalize_embeddings=True)
    return vector.tolist()


def warmup() -> None:
    """Call at startup to pre-load the model into memory."""
    _get_model()
