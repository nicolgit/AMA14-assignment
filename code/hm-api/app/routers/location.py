from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.db import get_engine

router = APIRouter()


@router.get("/location/{code}")
def get_location(code: str):
    """Return one location from the ``location`` table by location_code."""
    query = text(
        """
        SELECT location_code, location_name, place
        FROM location
        WHERE location_code = :location_code
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            row = conn.execute(query, {"location_code": code}).mappings().first()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    if not row:
        raise HTTPException(status_code=404, detail=f"location {code} not found")

    return dict(row)