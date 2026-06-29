from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.db import get_engine

router = APIRouter()


@router.get("/evaluations")
def list_evaluations():
    """Return all model evaluation metrics from the ``evaluation`` table."""
    query = text(
        """
        SELECT name, value
        FROM evaluation
        ORDER BY name
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            rows = conn.execute(query).mappings().all()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc
    return [dict(row) for row in rows]
