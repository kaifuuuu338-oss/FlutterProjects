from __future__ import annotations

import argparse
import os
from datetime import datetime
from pathlib import Path
from typing import List

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import classification_report, confusion_matrix, f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder


DEFAULT_TARGET = "nutrition_risk"


def _normalize_label(value: object) -> str:
    raw = str(value or "").strip().lower()
    if raw in {"low", "l"}:
        return "Low"
    if raw in {"medium", "moderate", "m"}:
        return "Medium"
    if raw in {"high", "h", "severe", "critical"}:
        return "High"
    raise ValueError(f"Unsupported nutrition_risk label: {value}")


def _drop_non_feature_cols(df: pd.DataFrame, target: str) -> pd.DataFrame:
    ignore = {
        target,
        "child_id",
        "aww_id",
        "awc_code",
        "created_at",
        "updated_at",
        "timestamp",
        "date",
    }
    keep = [c for c in df.columns if c not in ignore]
    return df[keep]


def _build_pipeline(numeric_features: List[str], categorical_features: List[str]) -> Pipeline:
    numeric_pipe = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="median")),
        ]
    )
    categorical_pipe = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="most_frequent")),
            ("onehot", OneHotEncoder(handle_unknown="ignore")),
        ]
    )
    preprocessor = ColumnTransformer(
        transformers=[
            ("num", numeric_pipe, numeric_features),
            ("cat", categorical_pipe, categorical_features),
        ]
    )
    clf = RandomForestClassifier(
        n_estimators=400,
        random_state=42,
        min_samples_leaf=2,
        class_weight="balanced",
        n_jobs=-1,
    )
    return Pipeline(
        steps=[
            ("preprocessor", preprocessor),
            ("classifier", clf),
        ]
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Train nutrition risk model (Low/Medium/High) and save .pkl artifact."
    )
    parser.add_argument("--csv", required=True, help="Path to training CSV with nutrition form features.")
    parser.add_argument("--target", default=DEFAULT_TARGET, help="Target column name (default: nutrition_risk).")
    parser.add_argument(
        "--out-dir",
        default=str(Path(__file__).resolve().parent / "trained_models"),
        help="Directory to save model artifacts.",
    )
    args = parser.parse_args()

    csv_path = Path(args.csv).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    if not csv_path.exists():
        raise FileNotFoundError(f"Training CSV not found: {csv_path}")

    df = pd.read_csv(csv_path)
    if args.target not in df.columns:
        raise KeyError(f"Target column '{args.target}' not found in {csv_path}")

    y = df[args.target].apply(_normalize_label)
    X = _drop_non_feature_cols(df, args.target).copy()

    # Convert booleans to integers for cleaner numeric handling.
    for col in X.columns:
        if X[col].dtype == bool:
            X[col] = X[col].astype(int)

    numeric_features = X.select_dtypes(include=[np.number, "bool"]).columns.tolist()
    categorical_features = [c for c in X.columns if c not in numeric_features]

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2,
        random_state=42,
        stratify=y,
    )

    pipeline = _build_pipeline(numeric_features, categorical_features)
    pipeline.fit(X_train, y_train)

    y_pred = pipeline.predict(X_test)
    f1_macro = f1_score(y_test, y_pred, average="macro")
    report = classification_report(y_test, y_pred, digits=4)
    cm = confusion_matrix(y_test, y_pred, labels=["Low", "Medium", "High"])

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    model_name = f"nutrition_risk_model_{ts}.pkl"
    metrics_name = f"nutrition_risk_metrics_{ts}.txt"
    model_path = out_dir / model_name
    metrics_path = out_dir / metrics_name

    artifact = {
        "model": pipeline,
        "feature_columns": X.columns.tolist(),
        "numeric_columns": numeric_features,
        "categorical_columns": categorical_features,
        "classes": ["Low", "Medium", "High"],
        "target": args.target,
        "trained_at": ts,
    }
    joblib.dump(artifact, model_path)

    metrics_text = (
        f"Data file: {csv_path}\n"
        f"Target column: {args.target}\n"
        f"Train rows: {len(X_train)}\n"
        f"Test rows: {len(X_test)}\n"
        f"Features: {len(X.columns)}\n"
        f"Numeric features: {len(numeric_features)}\n"
        f"Categorical features: {len(categorical_features)}\n"
        f"Macro F1: {f1_macro:.4f}\n\n"
        "Classification report:\n"
        f"{report}\n"
        "Confusion matrix (rows=true, cols=pred, labels=[Low, Medium, High]):\n"
        f"{cm}\n"
    )
    metrics_path.write_text(metrics_text, encoding="utf-8")

    print(f"Saved model: {model_path}")
    print(f"Saved metrics: {metrics_path}")
    print(f"Macro F1: {f1_macro:.4f}")


if __name__ == "__main__":
    main()

