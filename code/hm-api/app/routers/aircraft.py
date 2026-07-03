from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.db import get_engine

router = APIRouter()


@router.get("/aircraft")
def list_aircraft():
    """Return all aircraft from the ``aircraft`` table."""
    query = text(
        """
        SELECT aircraft_id, model, engine_count, engine_ids, operator,
               total_flight_cycles, status, msn, in_service_date,
               total_flight_hours, base_location
        FROM aircraft
        ORDER BY aircraft_id
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            rows = conn.execute(query).mappings().all()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc
    return [dict(row) for row in rows]


@router.get("/aircraft/{aircraftid}")
def get_aircraft(aircraftid: str):
    """Return one aircraft from the ``aircraft`` table by aircraft_id."""
    query = text(
        """
        SELECT aircraft_id, model, engine_count, engine_ids, operator,
               total_flight_cycles, status, msn, in_service_date,
               total_flight_hours, base_location
        FROM aircraft
        WHERE aircraft_id = :aircraft_id
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            row = conn.execute(query, {"aircraft_id": aircraftid}).mappings().first()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    if not row:
        raise HTTPException(status_code=404, detail=f"aircraft {aircraftid} not found")

    return dict(row)
