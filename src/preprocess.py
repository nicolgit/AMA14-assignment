from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler

BASE_COLUMNS = [
    "engine_id",
    "cycle",
    "op_setting_1",
    "op_setting_2",
    "op_setting_3",
]
SENSOR_COLUMNS = [f"sensor_{i}" for i in range(1, 22)]
ALL_COLUMNS = BASE_COLUMNS + SENSOR_COLUMNS


@dataclass
class SequenceDataset:
    features: np.ndarray
    targets: np.ndarray


def load_cmapss_file(path: str) -> pd.DataFrame:
    """Load C-MAPSS txt file with whitespace-separated values."""
    df = pd.read_csv(path, sep=r"\s+", header=None)
    if df.shape[1] < len(ALL_COLUMNS):
        raise ValueError(
            f"Unexpected column count {df.shape[1]} in {path}. "
            f"Expected at least {len(ALL_COLUMNS)}."
        )

    # Drop trailing empty columns that can appear in C-MAPSS files.
    df = df.iloc[:, : len(ALL_COLUMNS)].copy()
    df.columns = ALL_COLUMNS
    return df


def compute_rul(df: pd.DataFrame, max_rul: int | None = 130) -> pd.DataFrame:
    result = df.copy()
    max_cycle_per_engine = result.groupby("engine_id")["cycle"].transform("max")
    result["rul"] = max_cycle_per_engine - result["cycle"]
    if max_rul is not None:
        result["rul"] = result["rul"].clip(upper=max_rul)
    return result


def get_feature_columns() -> list[str]:
    # Standard setup keeps operating settings plus all sensors.
    return ["op_setting_1", "op_setting_2", "op_setting_3", *SENSOR_COLUMNS]


def split_engine_ids(
    engine_ids: Iterable[int],
    val_ratio: float,
    seed: int,
) -> tuple[np.ndarray, np.ndarray]:
    unique_ids = np.array(sorted(set(engine_ids)))
    rng = np.random.default_rng(seed)
    rng.shuffle(unique_ids)

    val_count = max(1, int(len(unique_ids) * val_ratio))
    val_ids = unique_ids[:val_count]
    train_ids = unique_ids[val_count:]

    if len(train_ids) == 0:
        raise ValueError("Validation split left zero engines for training.")
    return train_ids, val_ids


def fit_scaler(train_df: pd.DataFrame, feature_columns: list[str]) -> StandardScaler:
    scaler = StandardScaler()
    scaler.fit(train_df[feature_columns].astype(np.float32))
    return scaler


def build_sequences(
    df: pd.DataFrame,
    feature_columns: list[str],
    scaler: StandardScaler,
    window_size: int,
) -> SequenceDataset:
    features_list: list[np.ndarray] = []
    targets_list: list[float] = []

    for _, group in df.groupby("engine_id"):
        group = group.sort_values("cycle")
        scaled = scaler.transform(group[feature_columns].astype(np.float32))
        rul_values = group["rul"].to_numpy(dtype=np.float32)

        if len(group) < window_size:
            continue

        for end_idx in range(window_size - 1, len(group)):
            start_idx = end_idx - window_size + 1
            features_list.append(scaled[start_idx : end_idx + 1])
            targets_list.append(float(rul_values[end_idx]))

    if not features_list:
        raise ValueError("No sequences generated. Check window_size and dataset length.")

    return SequenceDataset(
        features=np.asarray(features_list, dtype=np.float32),
        targets=np.asarray(targets_list, dtype=np.float32),
    )


def build_last_sequences_per_engine(
    df: pd.DataFrame,
    feature_columns: list[str],
    scaler: StandardScaler,
    window_size: int,
) -> tuple[np.ndarray, np.ndarray]:
    engine_ids: list[int] = []
    sequences: list[np.ndarray] = []

    for engine_id, group in df.groupby("engine_id"):
        group = group.sort_values("cycle")
        scaled = scaler.transform(group[feature_columns].astype(np.float32))

        if len(group) >= window_size:
            seq = scaled[-window_size:]
        else:
            pad_count = window_size - len(group)
            pad_block = np.repeat(scaled[[0]], pad_count, axis=0)
            seq = np.concatenate([pad_block, scaled], axis=0)

        engine_ids.append(int(engine_id))
        sequences.append(seq)

    return np.asarray(engine_ids, dtype=np.int32), np.asarray(sequences, dtype=np.float32)
