from __future__ import annotations

import glob
import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import joblib
import pandas as pd


@dataclass
class LoadedNutritionModel:
    model: Any
    feature_columns: List[str]
    numeric_columns: List[str]
    categorical_columns: List[str]
    classes: List[str]
    model_path: str


def _latest_model_file(base_dir: str) -> str:
    explicit_name = os.getenv("ECD_NUTRITION_MODEL_FILE", "").strip()
    if explicit_name:
        if os.path.isabs(explicit_name):
            if os.path.exists(explicit_name):
                return explicit_name
            raise FileNotFoundError(f"Nutrition model file not found: {explicit_name}")
        candidate = os.path.join(base_dir, explicit_name)
        if os.path.exists(candidate):
            return candidate
        raise FileNotFoundError(f"Nutrition model file not found: {candidate}")

    pattern = os.path.join(base_dir, "nutrition_risk_model_*.pkl")
    candidates = sorted(glob.glob(pattern))
    if not candidates:
        raise FileNotFoundError(
            f"No nutrition model files found in {base_dir}. Expected pattern nutrition_risk_model_*.pkl"
        )
    return candidates[-1]


def load_nutrition_model(base_dir: Optional[str] = None) -> LoadedNutritionModel:
    if not base_dir:
        base_dir = os.getenv(
            "ECD_NUTRITION_MODEL_DIR",
            os.path.abspath(
                os.path.join(
                    os.path.dirname(__file__),
                    "..",
                    "model_assets",
                    "nutrition",
                    "trained_models",
                )
            ),
        )

    model_path = _latest_model_file(base_dir)
    artifact = joblib.load(model_path)

    if isinstance(artifact, dict):
        model = artifact.get("model")
        feature_columns = list(artifact.get("feature_columns") or [])
        numeric_columns = list(artifact.get("numeric_columns") or [])
        categorical_columns = list(artifact.get("categorical_columns") or [])
        classes = [str(x) for x in list(artifact.get("classes") or [])]
    else:
        model = artifact
        feature_columns = [str(x) for x in list(getattr(model, "feature_names_in_", []))]
        numeric_columns = []
        categorical_columns = []
        classes = [str(x) for x in list(getattr(model, "classes_", []))]

    if model is None or not hasattr(model, "predict"):
        raise ValueError(f"Loaded nutrition artifact is invalid: {model_path}")
    if not feature_columns:
        raise ValueError(
            f"Nutrition model does not expose feature columns. Re-train with train_nutrition_model.py. File: {model_path}"
        )

    if not classes and hasattr(model, "classes_"):
        classes = [str(x) for x in list(getattr(model, "classes_"))]

    return LoadedNutritionModel(
        model=model,
        feature_columns=feature_columns,
        numeric_columns=numeric_columns,
        categorical_columns=categorical_columns,
        classes=classes,
        model_path=model_path,
    )


def _to_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    try:
        return float(text)
    except Exception:
        return None


def _normalize_features(
    raw_features: Dict[str, Any], nutrition_model: LoadedNutritionModel
) -> pd.DataFrame:
    row: Dict[str, Any] = {}
    for col in nutrition_model.feature_columns:
        val = raw_features.get(col)
        if col in nutrition_model.numeric_columns:
            row[col] = _to_float(val)
        elif col in nutrition_model.categorical_columns:
            row[col] = "" if val is None else str(val)
        else:
            # If numeric/categorical split wasn't persisted, keep best-effort value.
            cast = _to_float(val)
            row[col] = cast if cast is not None else ("" if val is None else str(val))
    return pd.DataFrame([row], columns=nutrition_model.feature_columns)


def predict_nutrition_risk(
    raw_features: Dict[str, Any], nutrition_model: LoadedNutritionModel
) -> Dict[str, Any]:
    X = _normalize_features(raw_features, nutrition_model)
    pred = nutrition_model.model.predict(X)[0]
    risk = str(pred)

    confidence = None
    probabilities: Dict[str, float] = {}
    if hasattr(nutrition_model.model, "predict_proba"):
        proba = nutrition_model.model.predict_proba(X)[0]
        classes = nutrition_model.classes or [str(x) for x in list(getattr(nutrition_model.model, "classes_", []))]
        if classes and len(classes) == len(proba):
            probabilities = {str(classes[i]): float(proba[i]) for i in range(len(classes))}
            confidence = probabilities.get(risk)
        elif len(proba) > 0:
            confidence = float(max(proba))

    return {
        "nutrition_risk": risk,
        "confidence": confidence,
        "class_probabilities": probabilities,
        "model_source": "nutrition_model",
        "model_file": os.path.basename(nutrition_model.model_path),
    }

