from __future__ import annotations

import argparse
import json
import os
import pickle
from pathlib import Path

import mlflow
import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, TensorDataset

from preprocess import (
    build_sequences,
    compute_rul,
    fit_scaler,
    get_feature_columns,
    load_cmapss_file,
    split_engine_ids,
)


class CNNLSTMRegressor(nn.Module):
    def __init__(self, input_dim: int, conv_channels: int = 64, lstm_hidden: int = 64):
        super().__init__()
        self.conv = nn.Sequential(
            nn.Conv1d(input_dim, conv_channels, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.Conv1d(conv_channels, conv_channels, kernel_size=3, padding=1),
            nn.ReLU(),
        )
        self.lstm = nn.LSTM(
            input_size=conv_channels,
            hidden_size=lstm_hidden,
            num_layers=1,
            batch_first=True,
        )
        self.head = nn.Sequential(
            nn.Linear(lstm_hidden, 64),
            nn.ReLU(),
            nn.Linear(64, 1),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x shape: [batch, time, features]
        x = x.transpose(1, 2)  # [batch, features, time]
        x = self.conv(x)
        x = x.transpose(1, 2)  # [batch, time, channels]
        out, _ = self.lstm(x)
        last_hidden = out[:, -1, :]
        return self.head(last_hidden).squeeze(1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--train_data", type=str, required=True)
    parser.add_argument("--model_output", type=str, required=True)
    parser.add_argument("--window_size", type=int, default=30)
    parser.add_argument("--batch_size", type=int, default=128)
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--learning_rate", type=float, default=1e-3)
    parser.add_argument("--val_ratio", type=float, default=0.2)
    parser.add_argument("--max_rul", type=int, default=130)
    parser.add_argument("--seed", type=int, default=42)
    return parser.parse_args()


def set_seed(seed: int) -> None:
    np.random.seed(seed)
    torch.manual_seed(seed)


def evaluate(model: nn.Module, loader: DataLoader, device: torch.device) -> tuple[float, float]:
    model.eval()
    mae_meter = 0.0
    rmse_meter = 0.0
    count = 0

    with torch.no_grad():
        for xb, yb in loader:
            xb = xb.to(device)
            yb = yb.to(device)
            preds = model(xb)
            abs_err = torch.abs(preds - yb)
            sq_err = (preds - yb) ** 2

            batch_size = xb.size(0)
            mae_meter += abs_err.sum().item()
            rmse_meter += sq_err.sum().item()
            count += batch_size

    mae = mae_meter / max(1, count)
    rmse = (rmse_meter / max(1, count)) ** 0.5
    return mae, rmse


def train(
    train_data: str,
    model_output: str,
    window_size: int = 30,
    batch_size: int = 128,
    epochs: int = 20,
    learning_rate: float = 1e-3,
    val_ratio: float = 0.2,
    max_rul: int = 130,
    seed: int = 42,
    use_mlflow: bool = True,
) -> float:
    """Esegue il training CNN-LSTM e salva gli artefatti. Ritorna il best val RMSE.

    use_mlflow: abilita il tracking MLflow (job AML). In esecuzione interattiva
    (notebook) passare False: gli artefatti restano salvati su disco.
    """
    set_seed(seed)

    output_dir = Path(model_output)
    output_dir.mkdir(parents=True, exist_ok=True)

    if use_mlflow:
        mlflow.start_run()
        mlflow.log_params(
            {
                "window_size": window_size,
                "batch_size": batch_size,
                "epochs": epochs,
                "learning_rate": learning_rate,
                "val_ratio": val_ratio,
                "max_rul": max_rul,
                "seed": seed,
            }
        )

    raw_df = load_cmapss_file(train_data)
    df = compute_rul(raw_df, max_rul=max_rul)
    feature_columns = get_feature_columns()

    train_ids, val_ids = split_engine_ids(df["engine_id"].tolist(), val_ratio, seed)
    train_df = df[df["engine_id"].isin(train_ids)].copy()
    val_df = df[df["engine_id"].isin(val_ids)].copy()

    scaler = fit_scaler(train_df, feature_columns)

    train_seq = build_sequences(train_df, feature_columns, scaler, window_size)
    val_seq = build_sequences(val_df, feature_columns, scaler, window_size)

    train_ds = TensorDataset(
        torch.from_numpy(train_seq.features),
        torch.from_numpy(train_seq.targets),
    )
    val_ds = TensorDataset(
        torch.from_numpy(val_seq.features),
        torch.from_numpy(val_seq.targets),
    )

    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = CNNLSTMRegressor(input_dim=len(feature_columns)).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    loss_fn = nn.MSELoss()

    best_val_rmse = float("inf")
    best_state = None

    for epoch in range(1, epochs + 1):
        model.train()
        running_loss = 0.0
        sample_count = 0

        for xb, yb in train_loader:
            xb = xb.to(device)
            yb = yb.to(device)

            optimizer.zero_grad()
            preds = model(xb)
            loss = loss_fn(preds, yb)
            loss.backward()
            optimizer.step()

            batch = xb.size(0)
            running_loss += loss.item() * batch
            sample_count += batch

        train_loss = running_loss / max(1, sample_count)
        val_mae, val_rmse = evaluate(model, val_loader, device)

        if use_mlflow:
            mlflow.log_metric("train_mse", train_loss, step=epoch)
            mlflow.log_metric("val_mae", val_mae, step=epoch)
            mlflow.log_metric("val_rmse", val_rmse, step=epoch)

        print(
            f"Epoch {epoch:03d} | train_mse={train_loss:.5f} "
            f"| val_mae={val_mae:.5f} | val_rmse={val_rmse:.5f}"
        )

        if val_rmse < best_val_rmse:
            best_val_rmse = val_rmse
            best_state = {
                "state_dict": model.state_dict(),
                "window_size": window_size,
                "input_dim": len(feature_columns),
                "conv_channels": 64,
                "lstm_hidden": 64,
                "feature_columns": feature_columns,
                "max_rul": max_rul,
            }

    if best_state is None:
        raise RuntimeError("Training did not produce a checkpoint.")

    model_path = output_dir / "model.pt"
    torch.save(best_state, model_path)

    scaler_payload = {
        "scaler": scaler,
        "feature_columns": feature_columns,
    }
    scaler_path = output_dir / "scaler.pkl"
    with scaler_path.open("wb") as f:
        pickle.dump(scaler_payload, f)

    metrics_path = output_dir / "metrics.json"
    with metrics_path.open("w", encoding="utf-8") as f:
        json.dump({"best_val_rmse": best_val_rmse}, f, indent=2)

    if use_mlflow:
        # Gli artefatti (model.pt, scaler.pkl, metrics.json) sono gia persistiti
        # in output_dir = output 'model_output' del job, che lo step di evaluate
        # consuma direttamente. Si evita mlflow.log_artifact per non dipendere
        # dalla compatibilita azureml-mlflow/mlflow (azureml_artifacts_builder).
        mlflow.log_metric("best_val_rmse", best_val_rmse)
        mlflow.end_run()

    print(f"Saved artifacts to: {output_dir}")
    return best_val_rmse


def main() -> None:
    args = parse_args()
    train(
        train_data=args.train_data,
        model_output=args.model_output,
        window_size=args.window_size,
        batch_size=args.batch_size,
        epochs=args.epochs,
        learning_rate=args.learning_rate,
        val_ratio=args.val_ratio,
        max_rul=args.max_rul,
        seed=args.seed,
    )


if __name__ == "__main__":
    # AML sets this in command jobs; keep local execution compatible as well.
    os.environ.setdefault("AZUREML_RUN_ID", "local-run")
    main()
