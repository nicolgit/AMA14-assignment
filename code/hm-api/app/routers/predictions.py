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


@router.get("/predictions/{engineid}")
def get_prediction_for_engine(engineid: str):
    """Return one RUL prediction for the selected engine id."""
    query = text(
        """
        SELECT engine_id, predicted_rul
        FROM prediction
        WHERE CAST(engine_id AS TEXT) = :engine_id_text
           OR engine_id = CAST(:engine_id_num AS INTEGER)
        LIMIT 1
        """
    )

    # Engine ids in the app can be strings like "ENG-001" while predictions use int ids.
    digits = ''.join(ch for ch in engineid if ch.isdigit())
    engine_id_num = digits if digits else '-1'

    try:
        engine = get_engine()
        with engine.connect() as conn:
            row = conn.execute(
                query,
                {
                    "engine_id_text": engineid,
                    "engine_id_num": engine_id_num,
                },
            ).mappings().first()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    if not row:
        raise HTTPException(status_code=404, detail=f"prediction for engine {engineid} not found")

    return dict(row)
