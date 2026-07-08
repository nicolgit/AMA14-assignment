from math import erf, sqrt

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text

from app.db import get_engine

router = APIRouter()

DEFAULT_HORIZON_CYCLES = 30.0
YELLOW_FROM = 0.30
RED_FROM = 0.60


class MaintenanceUrgencyRequest(BaseModel):
    rul: float = Field(ge=0, description="Predicted RUL in cycles.")
    horizon_cycles: float = Field(
        default=DEFAULT_HORIZON_CYCLES,
        gt=0,
        description="Operational horizon in cycles.",
    )


class MaintenanceUrgencyResponse(BaseModel):
    level: int
    risk_probability: float
    explanation: str
    inputs: dict
    thresholds: dict


class EngineMaintenanceUrgencyResponse(BaseModel):
    engine_id: int
    predicted_rul: float
    level: int
    risk_probability: float
    explanation: str


def _normal_cdf(z: float) -> float:
    return 0.5 * (1.0 + erf(z / sqrt(2.0)))


def _classify_urgency(rul: float, horizon_cycles: float, mae: float, rmse: float) -> tuple[int, float, str]:
    z = (horizon_cycles + mae - rul) / rmse
    p_risk = _normal_cdf(z)

    if p_risk >= RED_FROM:
        level = 3
        explanation = "Rischio alto: pianificare intervento di manutenzione preventiva."
    elif p_risk >= YELLOW_FROM:
        level = 2
        explanation = "Rischio intermedio: vicini alla soglia, aumentare monitoraggio."
    else:
        level = 1
        explanation = "Rischio basso: non e necessario intervenire ora."

    return level, p_risk, explanation


def _fetch_metrics() -> tuple[float, float]:
    query = text(
        """
        SELECT LOWER(name) AS name, value
        FROM evaluation
        WHERE LOWER(name) IN ('mae', 'rmse')
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            rows = conn.execute(query).mappings().all()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    metric_by_name = {str(row["name"]): float(row["value"]) for row in rows}
    mae = metric_by_name.get("mae")
    rmse = metric_by_name.get("rmse")

    if mae is None or rmse is None:
        raise HTTPException(
            status_code=422,
            detail="missing required evaluation metrics: mae and rmse",
        )
    if rmse <= 0:
        raise HTTPException(status_code=422, detail="rmse must be > 0")

    return mae, rmse


@router.post("/maintenance/urgency", response_model=MaintenanceUrgencyResponse)
def maintenance_urgency(payload: MaintenanceUrgencyRequest):
    mae, rmse = _fetch_metrics()
    level, p_risk, explanation = _classify_urgency(
        rul=payload.rul,
        horizon_cycles=payload.horizon_cycles,
        mae=mae,
        rmse=rmse,
    )

    return MaintenanceUrgencyResponse(
        level=level,
        risk_probability=round(p_risk, 6),
        explanation=explanation,
        inputs={
            "rul": payload.rul,
            "horizon_cycles": payload.horizon_cycles,
            "mae": mae,
            "rmse": rmse,
        },
        thresholds={
            "yellow_from": YELLOW_FROM,
            "red_from": RED_FROM,
        },
    )


@router.get("/maintenance/urgency/engines", response_model=list[EngineMaintenanceUrgencyResponse])
def maintenance_urgency_by_engine(horizon_cycles: float = DEFAULT_HORIZON_CYCLES):
    if horizon_cycles <= 0:
        raise HTTPException(status_code=422, detail="horizon_cycles must be > 0")

    mae, rmse = _fetch_metrics()
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
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc

    output: list[EngineMaintenanceUrgencyResponse] = []
    for row in rows:
        predicted_rul = float(row["predicted_rul"])
        level, p_risk, explanation = _classify_urgency(
            rul=predicted_rul,
            horizon_cycles=horizon_cycles,
            mae=mae,
            rmse=rmse,
        )
        output.append(
            EngineMaintenanceUrgencyResponse(
                engine_id=int(row["engine_id"]),
                predicted_rul=predicted_rul,
                level=level,
                risk_probability=round(p_risk, 6),
                explanation=explanation,
            )
        )

    return output