from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.db import get_engine

router = APIRouter()


@router.get("/predictions")
def list_predictions():
    """Return all RUL predictions from the ``prediction`` table."""
    query = text(
        """
        SELECT engine_id, predicted_rul
        FROM prediction
        ORDER BY engine_id
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            rows = conn.execute(query).mappings().all()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc
    return [dict(row) for row in rows]
