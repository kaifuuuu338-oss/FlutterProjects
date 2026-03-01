from __future__ import annotations

import glob
import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

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


@dataclass
class LoadedDomainModels:
    models: Dict[str, Any]
    feature_order: Dict[str, List[str]]


@dataclass
class LoadedNeuroBehaviorModels:
    models: Dict[str, Any]
    feature_order: Dict[str, List[str]]


DOMAIN_KEYS = ["GM", "FM", "LC", "COG", "SE"]
NEURO_DOMAIN_KEYS = ["BPS_AUT", "BPS_ADHD", "BPS_BEH"]


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


def _candidate_domain_model_dirs(explicit_dir: Optional[str] = None) -> List[str]:
    here = os.path.dirname(__file__)
    candidates = []
    if explicit_dir:
        candidates.append(explicit_dir)
    candidates.extend(
        [
            os.path.join(here, "..", "model_assets", "domain_models"),
            os.path.join(here, "..", "model_assets", "model", "domain_models"),
            os.path.join(os.path.expanduser("~"), "Downloads"),
        ]
    )

    unique = []
    seen = set()
    for item in candidates:
        path = os.path.abspath(item)
        if path in seen:
            continue
        seen.add(path)
        unique.append(path)
    return unique


def load_domain_models(base_dir: Optional[str] = None) -> LoadedDomainModels:
    expected_files = {domain: f"domain_{domain}.pkl" for domain in DOMAIN_KEYS}
    selected_dir = None

    for candidate in _candidate_domain_model_dirs(base_dir):
        if all(os.path.exists(os.path.join(candidate, fname)) for fname in expected_files.values()):
            selected_dir = candidate
            break

    if selected_dir is None:
        searched = ", ".join(_candidate_domain_model_dirs(base_dir))
        raise FileNotFoundError(
            f"Missing domain model files ({', '.join(expected_files.values())}). "
            f"Searched: {searched}"
        )

    models: Dict[str, Any] = {}
    feature_order: Dict[str, List[str]] = {}
    for domain, file_name in expected_files.items():
        path = os.path.join(selected_dir, file_name)
        model = joblib.load(path)
        if not hasattr(model, "predict"):
            raise ValueError(f"domain model {path} does not support predict()")
        models[domain] = model
        if hasattr(model, "feature_names_in_"):
            feature_order[domain] = [str(x) for x in list(model.feature_names_in_)]
        else:
            n_features = int(getattr(model, "n_features_in_", 15))
            feature_order[domain] = [f"Q{i + 1}" for i in range(n_features)]

    return LoadedDomainModels(models=models, feature_order=feature_order)


def _candidate_neuro_model_dirs(explicit_dir: Optional[str] = None) -> List[str]:
    here = os.path.dirname(__file__)
    candidates = []
    if explicit_dir:
        candidates.append(explicit_dir)
    candidates.extend(
        [
            os.path.join(here, "..", "model_assets", "neuro_behavioral_models"),
            os.path.join(here, "..", "model_assets", "model", "neuro_behavioral_models"),
            os.path.join(os.path.expanduser("~"), "Downloads"),
        ]
    )

    unique = []
    seen = set()
    for item in candidates:
        path = os.path.abspath(item)
        if path in seen:
            continue
        seen.add(path)
        unique.append(path)
    return unique


def load_neuro_behavior_models(base_dir: Optional[str] = None) -> LoadedNeuroBehaviorModels:
    expected_files = {
        "BPS_AUT": "neuro_autism_delay_model.pkl",
        "BPS_ADHD": "neuro_adhd_delay_model.pkl",
        "BPS_BEH": "neuro_behavior_delay_model.pkl",
    }
    selected_dir = None

    for candidate in _candidate_neuro_model_dirs(base_dir):
        if all(os.path.exists(os.path.join(candidate, fname)) for fname in expected_files.values()):
            selected_dir = candidate
            break

    if selected_dir is None:
        searched = ", ".join(_candidate_neuro_model_dirs(base_dir))
        raise FileNotFoundError(
            f"Missing neuro behavioral model files ({', '.join(expected_files.values())}). "
            f"Searched: {searched}"
        )

    models: Dict[str, Any] = {}
    feature_order: Dict[str, List[str]] = {}
    for domain, file_name in expected_files.items():
        path = os.path.join(selected_dir, file_name)
        model = joblib.load(path)
        if not hasattr(model, "predict"):
            raise ValueError(f"neuro model {path} does not support predict()")
        models[domain] = model
        if hasattr(model, "feature_names_in_"):
            feature_order[domain] = [str(x) for x in list(model.feature_names_in_)]
        else:
            n_features = int(getattr(model, "n_features_in_", 15))
            feature_order[domain] = [f"GM_Q{i + 1}" for i in range(n_features)]

    return LoadedNeuroBehaviorModels(models=models, feature_order=feature_order)


def _delay_count(values: List[int]) -> int:
    return sum(1 for v in values if int(v) == 0)


def _normalize_binary_answers(values: List[int], target_len: int) -> List[int]:
    # Pad missing responses as 1 ("yes / no delay signal") to avoid false positives.
    normalized = [1] * max(target_len, 0)
    limit = min(len(values), target_len)
    for i in range(limit):
        try:
            normalized[i] = 1 if int(values[i]) != 0 else 0
        except Exception:
            normalized[i] = 0
    return normalized


def _delay_label_from_prob(delay_flag: int, delay_prob: float) -> str:
    if delay_flag <= 0:
        return "Low"
    if delay_prob >= 0.90:
        return "Critical"
    if delay_prob >= 0.75:
        return "High"
    return "Medium"


def _risk_rank(label: str) -> int:
    return {
        "low": 0,
        "medium": 1,
        "moderate": 1,
        "high": 2,
        "critical": 3,
    }.get(str(label).strip().lower(), 0)


def predict_domain_delays(payload: dict, domain_models: LoadedDomainModels) -> dict:
    domain_responses = payload.get("domain_responses", {}) or {}

    delay_summary: Dict[str, int] = {}
    domain_scores: Dict[str, str] = {}
    explanation: List[str] = []

    for domain in DOMAIN_KEYS:
        model = domain_models.models.get(domain)
        feature_names = domain_models.feature_order.get(domain, [f"Q{i}" for i in range(1, 16)])
        if model is None:
            continue

        raw_answers = domain_responses.get(domain, [])
        if not isinstance(raw_answers, list):
            raw_answers = []
        raw_answer_count = len(raw_answers)
        answers = _normalize_binary_answers(raw_answers, len(feature_names))
        feature_frame = pd.DataFrame(
            [{feature_names[i]: answers[i] for i in range(len(feature_names))}],
            columns=feature_names,
        )

        pred_class = int(model.predict(feature_frame)[0])
        classes = list(getattr(model, "classes_", [0, 1]))
        delay_class = 1 if 1 in classes else int(classes[-1])
        delay_flag = 1 if pred_class == delay_class else 0

        delay_prob = float(delay_flag)
        if hasattr(model, "predict_proba"):
            probs = model.predict_proba(feature_frame)[0]
            if delay_class in classes:
                delay_prob = float(probs[classes.index(delay_class)])
            elif len(probs) > 1:
                delay_prob = float(probs[1])
            elif len(probs) == 1:
                delay_prob = float(probs[0])

        domain_scores[domain] = _delay_label_from_prob(delay_flag, delay_prob)
        delay_summary[f"{domain}_delay"] = delay_flag
        explanation_text = (
            f"{domain}: {'delay predicted' if delay_flag else 'no delay predicted'} "
            f"(p={delay_prob:.2f})"
        )
        missing = max(len(feature_names) - raw_answer_count, 0)
        if missing > 0:
            explanation_text += f", padded {missing} missing responses"
        explanation.append(explanation_text)

    num_delays = sum(delay_summary.values())
    delay_summary["num_delays"] = num_delays

    if num_delays >= 4:
        risk_level = "Critical"
    elif num_delays >= 2:
        risk_level = "High"
    elif num_delays == 1:
        risk_level = "Medium"
    else:
        risk_level = "Low"

    if not explanation:
        explanation.append("No domain model predictions available.")

    return {
        "risk_level": risk_level,
        "domain_scores": domain_scores,
        "explanation": explanation,
        "delay_summary": delay_summary,
        "model_source": "domain_models",
    }


def predict_neuro_behavioral_risks(payload: dict, neuro_models: LoadedNeuroBehaviorModels) -> dict:
    domain_responses = payload.get("domain_responses", {}) or {}

    delay_summary: Dict[str, int] = {}
    domain_scores: Dict[str, str] = {}
    explanation: List[str] = []

    for domain in NEURO_DOMAIN_KEYS:
        model = neuro_models.models.get(domain)
        feature_names = neuro_models.feature_order.get(domain, [f"GM_Q{i + 1}" for i in range(15)])
        if model is None:
            continue

        raw_answers = domain_responses.get(domain, [])
        if not isinstance(raw_answers, list):
            raw_answers = []
        raw_answer_count = len(raw_answers)
        answers = _normalize_binary_answers(raw_answers, len(feature_names))
        feature_frame = pd.DataFrame(
            [{feature_names[i]: answers[i] for i in range(len(feature_names))}],
            columns=feature_names,
        )

        pred_class = int(model.predict(feature_frame)[0])
        classes = list(getattr(model, "classes_", [0, 1]))
        delay_class = 1 if 1 in classes else int(classes[-1])
        delay_flag = 1 if pred_class == delay_class else 0

        delay_prob = float(delay_flag)
        if hasattr(model, "predict_proba"):
            probs = model.predict_proba(feature_frame)[0]
            if delay_class in classes:
                delay_prob = float(probs[classes.index(delay_class)])
            elif len(probs) > 1:
                delay_prob = float(probs[1])
            elif len(probs) == 1:
                delay_prob = float(probs[0])

        domain_scores[domain] = _delay_label_from_prob(delay_flag, delay_prob)
        delay_summary[f"{domain}_delay"] = delay_flag
        explanation_text = (
            f"{domain}: {'delay predicted' if delay_flag else 'no delay predicted'} "
            f"(p={delay_prob:.2f})"
        )
        missing = max(len(feature_names) - raw_answer_count, 0)
        if missing > 0:
            explanation_text += f", padded {missing} missing responses"
        explanation.append(explanation_text)

    num_delays = sum(delay_summary.values())
    delay_summary["num_delays"] = num_delays

    if domain_scores:
        risk_level = max(domain_scores.values(), key=_risk_rank)
    else:
        risk_level = "Low"

    if not explanation:
        explanation.append("No neuro behavioral model predictions available.")

    return {
        "risk_level": risk_level,
        "domain_scores": domain_scores,
        "explanation": explanation,
        "delay_summary": delay_summary,
        "model_source": "neuro_behavioral_models",
    }


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
