from typing import List, Optional
from fastembed import TextEmbedding

_model: Optional[TextEmbedding] = None


def _get_model() -> TextEmbedding:
    global _model
    if _model is None:
        _model = TextEmbedding("BAAI/bge-small-en-v1.5")
    return _model


def embed(text: str) -> List[float]:
    model = _get_model()
    vectors = list(model.embed([text]))
    return vectors[0].tolist()


def warmup() -> None:
    _get_model()
