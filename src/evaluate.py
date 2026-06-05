from __future__ import annotations

import argparse
import json
import pickle
from pathlib import Path

import numpy as np
import pandas as pd
import torch

from preprocess import build_last_sequences_per_engine, get_feature_columns, load_cmapss_file
from train import CNNLSTMRegressor


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--test_data", type=str, required=True)
    parser.add_argument("--model_dir", type=str, required=True)
    parser.add_argument("--output_dir", type=str, required=True)
    parser.add_argument("--rul_labels", type=str, default="")
    parser.add_argument("--batch_size", type=int, default=256)
    return parser.parse_args()


def load_labels(path: str) -> pd.DataFrame:
    labels = pd.read_csv(path, sep=r"\s+", header=None)
    labels = labels.iloc[:, [0]].copy()
    labels.columns = ["rul_true"]
    labels["engine_id"] = np.arange(1, len(labels) + 1)
    return labels[["engine_id", "rul_true"]]


def main() -> None:
    args = parse_args()

    model_dir = Path(args.model_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    checkpoint = torch.load(model_dir / "model.pt", map_location="cpu")
    with (model_dir / "scaler.pkl").open("rb") as f:
        scaler_payload = pickle.load(f)

    feature_columns = checkpoint.get("feature_columns") or scaler_payload.get("feature_columns")
    if not feature_columns:
        feature_columns = get_feature_columns()

    scaler = scaler_payload["scaler"]
    window_size = int(checkpoint["window_size"])

    model = CNNLSTMRegressor(
        input_dim=int(checkpoint["input_dim"]),
        conv_channels=int(checkpoint.get("conv_channels", 64)),
        lstm_hidden=int(checkpoint.get("lstm_hidden", 64)),
    )
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()

    test_df = load_cmapss_file(args.test_data)
    engine_ids, seq = build_last_sequences_per_engine(
        test_df,
        feature_columns=feature_columns,
        scaler=scaler,
        window_size=window_size,
    )

    preds: list[float] = []
    with torch.no_grad():
        for idx in range(0, len(seq), args.batch_size):
            batch = torch.from_numpy(seq[idx : idx + args.batch_size])
            out = model(batch).numpy()
            preds.extend(out.tolist())

    pred_df = pd.DataFrame(
        {
            "engine_id": engine_ids,
            "predicted_rul": np.maximum(np.array(preds, dtype=np.float32), 0.0),
        }
    ).sort_values("engine_id")

    predictions_path = output_dir / "predictions.csv"
    pred_df.to_csv(predictions_path, index=False)

    metrics = {}
    if args.rul_labels:
        labels_df = load_labels(args.rul_labels)
        merged = pred_df.merge(labels_df, on="engine_id", how="inner")
        if not merged.empty:
            abs_err = np.abs(merged["predicted_rul"] - merged["rul_true"])
            sq_err = (merged["predicted_rul"] - merged["rul_true"]) ** 2
            metrics["mae"] = float(abs_err.mean())
            metrics["rmse"] = float(np.sqrt(sq_err.mean()))

    metrics_path = output_dir / "evaluation.json"
    with metrics_path.open("w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2)

    print(f"Saved predictions to: {predictions_path}")
    print(f"Saved metrics to: {metrics_path}")


if __name__ == "__main__":
    main()
