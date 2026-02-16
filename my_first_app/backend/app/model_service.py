from __future__ import annotations

import glob
import os
from dataclasses import dataclass
from typing import Dict, List, Tuple

import joblib
import pandas as pd


@dataclass
class LoadedArtifacts:
    model: object
    scaler: object
    encoders: Dict[str, object]
    feature_columns: List[str]
    categorical_columns: List[str]
    numeric_columns: List[str]


def _find_latest(pattern: str) -> str:
    files = glob.glob(pattern)
    if not files:
        raise FileNotFoundError(f"No files found for pattern: {pattern}")
    files.sort()
    return files[-1]


def load_artifacts(base_dir: str) -> LoadedArtifacts:
    model_file = os.getenv("ECD_MODEL_FILE", "baseline_risk_stacking_smotenc_20260213_185809.pkl")
    scaler_file = os.getenv("ECD_SCALER_FILE", "scaler_20260213_185809.pkl")
    encoders_file = os.getenv("ECD_ENCODERS_FILE", "encoders_20260213_185809.pkl")

    model_path = os.path.join(base_dir, model_file)
    scaler_path = os.path.join(base_dir, scaler_file)
    encoders_path = os.path.join(base_dir, encoders_file)

    for label, path in [("model", model_path), ("scaler", scaler_path), ("encoders", encoders_path)]:
        if not os.path.exists(path):
            raise FileNotFoundError(f"Missing {label} artifact: {path}")

    model = joblib.load(model_path)
    scaler = joblib.load(scaler_path)
    encoders = joblib.load(encoders_path)

    feature_columns = list(model.feature_names_in_)
    categorical_columns = [c for c in feature_columns if c in encoders]
    numeric_columns = [c for c in feature_columns if c not in categorical_columns]

    return LoadedArtifacts(
        model=model,
        scaler=scaler,
        encoders=encoders,
        feature_columns=feature_columns,
        categorical_columns=categorical_columns,
        numeric_columns=numeric_columns,
    )


def _delay_count(values: List[int]) -> int:
    return sum(1 for v in values if int(v) == 0)


def _domain_level(values: List[int]) -> str:
    if not values:
        return "Low"
    misses = _delay_count(values)
    ratio = misses / len(values)
    if ratio >= 0.75:
        return "Critical"
    if ratio >= 0.5:
        return "High"
    if ratio >= 0.25:
        return "Medium"
    return "Low"


def _risk_points(risk: str, high_points: int, moderate_points: int = 0) -> int:
    r = str(risk).strip().lower()
    if r == "high":
        return high_points
    if r in {"moderate", "medium"}:
        return moderate_points
    return 0


def _baseline_risk_from_score(score: int) -> str:
    if score <= 10:
        return "Low"
    if score <= 25:
        return "Medium"
    return "High"


def build_features(payload: dict, artifacts: LoadedArtifacts) -> Tuple[pd.DataFrame, Dict[str, str], List[str], int]:
    domain_responses = payload.get("domain_responses", {})
    gm = domain_responses.get("GM", [])
    fm = domain_responses.get("FM", [])
    lc = domain_responses.get("LC", [])
    cog = domain_responses.get("COG", [])
    se = domain_responses.get("SE", [])

    gm_delay = _delay_count(gm)
    fm_delay = _delay_count(fm)
    lc_delay = _delay_count(lc)
    cog_delay = _delay_count(cog)
    se_delay = _delay_count(se)
    num_delays = gm_delay + fm_delay + lc_delay + cog_delay + se_delay

    domain_scores = {
        "GM": _domain_level(gm),
        "FM": _domain_level(fm),
        "LC": _domain_level(lc),
        "COG": _domain_level(cog),
        "SE": _domain_level(se),
    }

    # Optional context (if frontend sends later); otherwise defaults are used.
    raw_features = {
        "age_months": int(payload.get("age_months", 0)),
        "gender": payload.get("gender", "M"),
        "mandal": payload.get("mandal", "Demo Mandal"),
        "district": payload.get("district", "Demo District"),
        "assessment_cycle": payload.get("assessment_cycle", "Baseline"),
        "GM_delay": gm_delay,
        "FM_delay": fm_delay,
        "LC_delay": lc_delay,
        "COG_delay": cog_delay,
        "SE_delay": se_delay,
        "num_delays": num_delays,
        "autism_risk": payload.get("autism_risk", "Low"),
        "adhd_risk": payload.get("adhd_risk", "Low"),
        "behavior_risk": payload.get("behavior_risk", "Low"),
        "underweight": int(payload.get("underweight", 0)),
        "stunting": int(payload.get("stunting", 0)),
        "wasting": int(payload.get("wasting", 0)),
        "anemia": int(payload.get("anemia", 0)),
        "nutrition_score": float(payload.get("nutrition_score", 75)),
        "nutrition_risk": payload.get("nutrition_risk", "Low"),
        "parent_child_interaction_score": float(payload.get("parent_child_interaction_score", 3)),
        "parent_mental_health_score": float(payload.get("parent_mental_health_score", 3)),
        "home_stimulation_score": float(payload.get("home_stimulation_score", 3)),
        "play_materials": payload.get("play_materials", "Adequate"),
        "caregiver_engagement": payload.get("caregiver_engagement", "Good"),
        "language_exposure": payload.get("language_exposure", "Adequate"),
        "safe_water": payload.get("safe_water", "Yes"),
        "toilet_facility": payload.get("toilet_facility", "Yes"),
    }

    # Align with model feature order and safe-encode categoricals.
    row = {}
    for col in artifacts.feature_columns:
        val = raw_features.get(col, 0)
        if col in artifacts.categorical_columns:
            encoder = artifacts.encoders[col]
            classes = list(encoder.classes_)
            val_s = str(val)
            if val_s not in classes:
                val_s = classes[0]
            row[col] = int(encoder.transform([val_s])[0])
        else:
            row[col] = float(val)

    X = pd.DataFrame([row], columns=artifacts.feature_columns)

    # Scale numeric columns exactly as in training.
    X_scaled = X.copy()
    X_scaled[artifacts.numeric_columns] = artifacts.scaler.transform(X[artifacts.numeric_columns])

    explanation = []
    for d, misses in [("GM", gm_delay), ("FM", fm_delay), ("LC", lc_delay), ("COG", cog_delay), ("SE", se_delay)]:
        if misses > 0:
            explanation.append(f"{misses} {d} milestones missed")
    if lc_delay > 0:
        explanation.append("Language and communication delays detected")
    if se_delay > 0:
        explanation.append("Social interaction score is low")
    if not explanation:
        explanation.append("No major missed milestones in current screening")

    return X_scaled, domain_scores, explanation, num_delays


def predict_risk(payload: dict, artifacts: LoadedArtifacts) -> dict:
    X_scaled, domain_scores, explanation, num_delays = build_features(payload, artifacts)

    pred = artifacts.model.predict(X_scaled)[0]
    model_risk = str(pred)

    domain_responses = payload.get("domain_responses", {})
    gm_delay_flag = 1 if _delay_count(domain_responses.get("GM", [])) >= 2 else 0
    fm_delay_flag = 1 if _delay_count(domain_responses.get("FM", [])) >= 2 else 0
    lc_delay_flag = 1 if _delay_count(domain_responses.get("LC", [])) >= 2 else 0
    cog_delay_flag = 1 if _delay_count(domain_responses.get("COG", [])) >= 2 else 0
    se_delay_flag = 1 if _delay_count(domain_responses.get("SE", [])) >= 2 else 0
    domain_delay_points = 5 * (gm_delay_flag + fm_delay_flag + lc_delay_flag + cog_delay_flag + se_delay_flag)

    baseline_score = (
        domain_delay_points
        + _risk_points(payload.get("autism_risk", "Low"), high_points=15, moderate_points=8)
        + _risk_points(payload.get("adhd_risk", "Low"), high_points=8, moderate_points=4)
        + _risk_points(payload.get("behavior_risk", "Low"), high_points=7, moderate_points=0)
    )

    risk_level = _baseline_risk_from_score(baseline_score)

    # Business rule escalation to support Critical state in app flow.
    critical_domains = sum(1 for v in domain_scores.values() if v == "Critical")
    if critical_domains >= 2 or num_delays >= 6:
        risk_level = "Critical"

    delay_summary = {
        "GM_delay": gm_delay_flag,
        "FM_delay": fm_delay_flag,
        "LC_delay": lc_delay_flag,
        "COG_delay": cog_delay_flag,
        "SE_delay": se_delay_flag,
    }
    delay_summary["num_delays"] = (
        delay_summary["GM_delay"]
        + delay_summary["FM_delay"]
        + delay_summary["LC_delay"]
        + delay_summary["COG_delay"]
        + delay_summary["SE_delay"]
    )

    return {
        "risk_level": risk_level,
        "baseline_score": baseline_score,
        "model_risk": model_risk,
        "domain_scores": domain_scores,
        "explanation": explanation,
        "delay_summary": delay_summary,
    }
