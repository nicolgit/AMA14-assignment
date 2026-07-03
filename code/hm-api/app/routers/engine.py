from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.db import get_engine

router = APIRouter()


@router.get("/engine/{engineid}")
def get_engine_data(engineid: int):
    """Return all cycles from ``engine_data`` for the selected engine id."""
    query = text(
        """
        SELECT unit_number, time_in_cycles,
               operational_setting_1, operational_setting_2, operational_setting_3,
               sensor_measurement_1, sensor_measurement_2, sensor_measurement_3,
               sensor_measurement_4, sensor_measurement_5, sensor_measurement_6,
               sensor_measurement_7, sensor_measurement_8, sensor_measurement_9,
               sensor_measurement_10, sensor_measurement_11, sensor_measurement_12,
               sensor_measurement_13, sensor_measurement_14, sensor_measurement_15,
               sensor_measurement_16, sensor_measurement_17, sensor_measurement_18,
               sensor_measurement_19, sensor_measurement_20, sensor_measurement_21
        FROM engine_data
        WHERE unit_number = :engine_id
        ORDER BY time_in_cycles
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            rows = conn.execute(query, {"engine_id": engineid}).mappings().all()
    except Exception as exc:  # surface a clean 503 instead of a 500 stack trace
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    if not rows:
        raise HTTPException(status_code=404, detail=f"engine {engineid} not found")

    return [dict(row) for row in rows]