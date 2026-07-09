from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text

from app.db import get_engine

router = APIRouter()


class SupplyPartRequest(BaseModel):
    part_number: str = Field(min_length=1)
    quantity: int = Field(default=1, ge=1)
    supplier_lead_time_cycles: float | None = Field(default=None, gt=0)
    supplier_cost: float | None = Field(default=None, ge=0)


class SupplyDecisionRequest(BaseModel):
    aircraft_id: str | None = None
    location_id: str = Field(min_length=1, description="Destination location code")
    rul_cycles: float = Field(ge=0)
    risk_30: float = Field(ge=0, le=1)
    parts: list[SupplyPartRequest] = Field(min_length=1)
    top_k: int = Field(default=3, ge=1, le=20)
    lambda_weight: float = Field(default=500.0, gt=0)
    mu_weight: float = Field(default=50.0, ge=0)
    local_handling_cost: float = Field(default=30.0, ge=0)
    default_supplier_lead_time_cycles: float = Field(default=18.0, gt=0)
    default_supplier_cost: float = Field(default=1200.0, ge=0)


class SupplyOption(BaseModel):
    decision: Literal["local", "transfer", "order", "emergency"]
    selected_origin: str | None = None
    eta_cycles: float
    total_cost: float
    urgency_score: float
    priority_class: Literal["RED", "YELLOW", "GREEN"]
    score: float
    feasible: bool
    reason_codes: list[str]


class SupplyPartDecision(BaseModel):
    part_number: str
    quantity: int
    decision: Literal["local", "transfer", "order", "emergency"]
    selected_origin: str | None = None
    eta_cycles: float
    total_cost: float
    urgency_score: float
    priority_class: Literal["RED", "YELLOW", "GREEN"]
    reason_codes: list[str]
    top_k_options: list[SupplyOption]


class SupplyDecisionResponse(BaseModel):
    aircraft_id: str | None
    location_id: str
    deadline_cycles: float
    urgency_score: float
    priority_class: Literal["RED", "YELLOW", "GREEN"]
    decisions: list[SupplyPartDecision]


class SparePartOption(BaseModel):
    part_number: str
    name: str


def _compute_urgency(rul_cycles: float, risk_30: float) -> tuple[float, float, str]:
    horizon = min(rul_cycles, 30.0)
    urgency = 0.6 * risk_30 + 0.4 * (1.0 - (horizon / 30.0))
    buffer_cycles = max(1.0, 0.2 * horizon)
    deadline = max(0.0, horizon - buffer_cycles)

    if risk_30 >= 0.60 or rul_cycles <= 10:
        priority = "RED"
    elif (0.30 <= risk_30 < 0.60) or (10 < rul_cycles <= 20):
        priority = "YELLOW"
    else:
        priority = "GREEN"

    return urgency, deadline, priority


def _fetch_inventory(part_number: str) -> dict[str, dict[str, int]]:
    query = text(
        """
        SELECT
            location,
            COALESCE(on_hand, 0) AS on_hand,
            COALESCE(reserved, 0) AS reserved,
            COALESCE(min_stock, 0) AS min_stock
        FROM spare_part_location
        WHERE part_number = :part_number
        """
    )
    engine = get_engine()
    with engine.connect() as conn:
        rows = conn.execute(query, {"part_number": part_number}).mappings().all()

    out: dict[str, dict[str, int]] = {}
    for row in rows:
        on_hand = int(row["on_hand"])
        reserved = int(row["reserved"])
        min_stock = int(row["min_stock"])
        out[str(row["location"])] = {
            "on_hand": on_hand,
            "reserved": reserved,
            "min_stock": min_stock,
            "available": on_hand - reserved,
        }
    return out


def _fetch_transfers(destination: str) -> list[dict]:
    query = text(
        """
        SELECT
            location_1 AS origin,
            location_2 AS destination,
            COALESCE(distance, 0) AS distance,
            COALESCE(transfer_time, 99999) AS transfer_time,
            COALESCE(transfer_cost, 0) AS transfer_cost
        FROM location_distance
        WHERE location_2 = :destination
        """
    )
    engine = get_engine()
    with engine.connect() as conn:
        rows = conn.execute(query, {"destination": destination}).mappings().all()
    return [dict(r) for r in rows]


def _exists_location(location_id: str) -> bool:
    query = text("SELECT 1 FROM location WHERE location_code = :location_id LIMIT 1")
    engine = get_engine()
    with engine.connect() as conn:
        row = conn.execute(query, {"location_id": location_id}).first()
    return row is not None


def _exists_part(part_number: str) -> bool:
    query = text("SELECT 1 FROM spare_part WHERE part_number = :part_number LIMIT 1")
    engine = get_engine()
    with engine.connect() as conn:
        row = conn.execute(query, {"part_number": part_number}).first()
    return row is not None


@router.get("/supply/parts", response_model=list[SparePartOption])
def list_spare_parts():
    query = text(
        """
        SELECT part_number, name
        FROM spare_part
        ORDER BY part_number
        """
    )
    try:
        engine = get_engine()
        with engine.connect() as conn:
            rows = conn.execute(query).mappings().all()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc
    return [dict(row) for row in rows]


@router.post("/supply/decision", response_model=SupplyDecisionResponse)
def supply_decision(payload: SupplyDecisionRequest):
    try:
        if not _exists_location(payload.location_id):
            raise HTTPException(status_code=404, detail=f"location {payload.location_id} not found")

        urgency, deadline, priority = _compute_urgency(payload.rul_cycles, payload.risk_30)

        transfers = _fetch_transfers(payload.location_id)

        decisions: list[SupplyPartDecision] = []

        for part in payload.parts:
            if not _exists_part(part.part_number):
                raise HTTPException(status_code=404, detail=f"part {part.part_number} not found")

            supplier_eta = (
                part.supplier_lead_time_cycles
                if part.supplier_lead_time_cycles is not None
                else payload.default_supplier_lead_time_cycles
            )
            supplier_cost = (
                part.supplier_cost
                if part.supplier_cost is not None
                else payload.default_supplier_cost
            )

            inventory = _fetch_inventory(part.part_number)
            options: list[dict] = []

            local_stock = inventory.get(payload.location_id)
            if local_stock and local_stock["available"] >= part.quantity:
                eta = 0.0
                base_cost = payload.local_handling_cost * part.quantity
                delay_penalty = payload.lambda_weight * urgency * max(0.0, eta - deadline)
                score = base_cost + delay_penalty
                options.append(
                    {
                        "decision": "local",
                        "selected_origin": payload.location_id,
                        "eta_cycles": eta,
                        "total_cost": round(base_cost, 3),
                        "score": round(score, 3),
                        "feasible": eta <= deadline,
                        "reason_codes": ["LOCAL_STOCK_AVAILABLE"],
                    }
                )

            for t in transfers:
                origin = str(t["origin"])
                if origin == payload.location_id:
                    continue

                donor_stock = inventory.get(origin)
                if not donor_stock:
                    continue

                if donor_stock["available"] < part.quantity:
                    continue

                post_move_on_hand = donor_stock["on_hand"] - part.quantity
                min_stock = donor_stock["min_stock"]
                eta = float(t["transfer_time"])
                base_cost = float(t["transfer_cost"]) * part.quantity

                donor_scarcity = max(0.0, float(min_stock - post_move_on_hand))
                delay_penalty = payload.lambda_weight * urgency * max(0.0, eta - deadline)
                stock_penalty = payload.mu_weight * donor_scarcity
                score = base_cost + delay_penalty + stock_penalty

                reason_codes = ["TRANSFER_CANDIDATE"]
                feasible = eta <= deadline and post_move_on_hand >= min_stock

                if post_move_on_hand < min_stock:
                    reason_codes.append("DONOR_MIN_STOCK_VIOLATION")

                options.append(
                    {
                        "decision": "transfer",
                        "selected_origin": origin,
                        "eta_cycles": eta,
                        "total_cost": round(base_cost, 3),
                        "score": round(score, 3),
                        "feasible": feasible,
                        "reason_codes": reason_codes,
                    }
                )

            order_eta = float(supplier_eta)
            order_base_cost = float(supplier_cost) * part.quantity
            order_delay_penalty = payload.lambda_weight * urgency * max(0.0, order_eta - deadline)
            order_score = order_base_cost + order_delay_penalty
            options.append(
                {
                    "decision": "order",
                    "selected_origin": None,
                    "eta_cycles": order_eta,
                    "total_cost": round(order_base_cost, 3),
                    "score": round(order_score, 3),
                    "feasible": order_eta <= deadline,
                    "reason_codes": ["SUPPLIER_ORDER"],
                }
            )

            if not options:
                raise HTTPException(status_code=422, detail=f"no options generated for part {part.part_number}")

            sorted_options = sorted(options, key=lambda x: (x["score"], x["eta_cycles"], x["total_cost"]))
            feasible_options = [x for x in sorted_options if x["feasible"]]

            if feasible_options:
                selected = dict(feasible_options[0])
                selected["reason_codes"] = selected["reason_codes"] + ["CHEAPEST_IN_DEADLINE"]
            else:
                if priority == "RED":
                    red_candidates = [x for x in sorted_options if x["decision"] in {"local", "transfer", "order"}]
                    selected = dict(sorted(red_candidates, key=lambda x: (x["eta_cycles"], x["score"]))[0])
                    selected["decision"] = "emergency"
                    selected["reason_codes"] = selected["reason_codes"] + ["ESCALATION_RED"]
                else:
                    selected = dict(sorted_options[0])
                    selected["reason_codes"] = selected["reason_codes"] + ["ALERT_PLANNING", "OUT_OF_DEADLINE"]

            top_ranked = sorted_options[: payload.top_k]
            top_k_options = [
                SupplyOption(
                    decision=o["decision"],
                    selected_origin=o["selected_origin"],
                    eta_cycles=float(o["eta_cycles"]),
                    total_cost=float(o["total_cost"]),
                    urgency_score=round(urgency, 6),
                    priority_class=priority,
                    score=float(o["score"]),
                    feasible=bool(o["feasible"]),
                    reason_codes=o["reason_codes"],
                )
                for o in top_ranked
            ]

            decisions.append(
                SupplyPartDecision(
                    part_number=part.part_number,
                    quantity=part.quantity,
                    decision=selected["decision"],
                    selected_origin=selected["selected_origin"],
                    eta_cycles=float(selected["eta_cycles"]),
                    total_cost=float(selected["total_cost"]),
                    urgency_score=round(urgency, 6),
                    priority_class=priority,
                    reason_codes=selected["reason_codes"],
                    top_k_options=top_k_options,
                )
            )

        return SupplyDecisionResponse(
            aircraft_id=payload.aircraft_id,
            location_id=payload.location_id,
            deadline_cycles=round(deadline, 6),
            urgency_score=round(urgency, 6),
            priority_class=priority,
            decisions=decisions,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc
