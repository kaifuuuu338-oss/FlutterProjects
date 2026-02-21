import json
from urllib.parse import urlencode
from urllib.request import urlopen

from django.conf import settings
from django.http import JsonResponse
from django.shortcuts import redirect, render


def _fetch_monitoring(role: str, location_id: str = "") -> dict:
    query = urlencode({"role": role, "location_id": location_id})
    url = f"{settings.FASTAPI_BASE_URL.rstrip('/')}/analytics/monitoring?{query}"
    try:
        with urlopen(url, timeout=8) as response:
            body = response.read().decode("utf-8")
            data = json.loads(body)
            return _normalize_monitoring_payload(data)
    except Exception as exc:
        return _normalize_monitoring_payload({
            "error": f"Unable to fetch analytics from {url}: {exc}",
            "summary": {
                "total_children": 0,
                "screened_latest": 0,
                "screening_coverage_pct": 0.0,
                "pending_referrals": 0,
                "followup_due": 0,
                "followup_compliance_pct": 0.0,
            },
            "risk_distribution": {"Low": 0, "Medium": 0, "High": 0, "Critical": 0},
            "priority_children": [],
            "high_risk_children": [],
        })


def _normalize_monitoring_payload(data: dict) -> dict:
    normalized = dict(data or {})

    # Ensure iterable list fields for template loops.
    high_rows = normalized.get("high_risk_children_rows")
    high_field = normalized.get("high_risk_children")
    if isinstance(high_field, list):
        normalized["high_risk_children"] = high_field
    elif isinstance(high_rows, list):
        normalized["high_risk_children"] = high_rows
    else:
        normalized["high_risk_children"] = []

    priority_field = normalized.get("priority_children")
    if not isinstance(priority_field, list):
        normalized["priority_children"] = []
    else:
        cleaned_priority = []
        for row in priority_field:
            if not isinstance(row, dict):
                continue
            risk = row.get("risk_category") or row.get("risk_level") or "Low"
            cleaned_priority.append({
                **row,
                "risk_category": str(risk),
                "age_months": row.get("age_months", "-"),
            })
        normalized["priority_children"] = cleaned_priority

    cleaned_high = []
    for row in normalized["high_risk_children"]:
        if not isinstance(row, dict):
            continue
        risk = row.get("risk_category") or row.get("risk_level") or "High"
        cleaned_high.append({
            **row,
            "risk_category": str(risk),
            "domain_affected": row.get("domain_affected", "Multiple"),
            "referral_status": row.get("referral_status", "Not Referred"),
            "days_since_flagged": row.get("days_since_flagged", 0),
        })
    normalized["high_risk_children"] = cleaned_high

    # Normalize risk distribution keys.
    rd = normalized.get("risk_distribution")
    if not isinstance(rd, dict):
        rd = {}
    normalized["risk_distribution"] = {
        "Low": int(rd.get("Low", 0) or 0),
        "Medium": int(rd.get("Medium", 0) or 0),
        "High": int(rd.get("High", 0) or 0),
        "Critical": int(rd.get("Critical", 0) or 0),
    }

    summary = normalized.get("summary")
    if not isinstance(summary, dict):
        summary = {}
    summary.setdefault("total_children", int(normalized.get("total_children", 0) or 0))
    summary.setdefault("screened_latest", int(normalized.get("screened_latest", 0) or 0))
    summary.setdefault("screening_coverage_pct", float(normalized.get("screening_coverage_pct", 0.0) or 0.0))
    summary.setdefault("pending_referrals", int(normalized.get("pending_referrals", 0) or 0))
    summary.setdefault("followup_due", int(normalized.get("followup_due", 0) or 0))
    summary.setdefault("followup_compliance_pct", float(normalized.get("followup_compliance_pct", 0.0) or 0.0))
    normalized["summary"] = summary

    return normalized


def _render_role_dashboard(request, role: str, title: str):
    location_id = (request.GET.get("location_id") or "").strip()
    data = _fetch_monitoring(role, location_id)
    context = {
        "role": role.upper(),
        "title": title,
        "location_id": location_id,
        "data": data,
    }
    return render(request, "monitoring/role_dashboard.html", context)


def home(request):
    return redirect("monitoring_state")


def aww_dashboard(request):
    return _render_role_dashboard(request, "aww", "AWW Dashboard")


def supervisor_dashboard(request):
    return _render_role_dashboard(request, "supervisor", "Supervisor Dashboard")


def cdpo_dashboard(request):
    return _render_role_dashboard(request, "cdpo", "CDPO / Mandal Dashboard")


def district_dashboard(request):
    return _render_role_dashboard(request, "district", "District Dashboard")


def state_dashboard(request):
    return _render_role_dashboard(request, "state", "State Dashboard")


def monitoring_api_proxy(request):
    role = (request.GET.get("role") or "state").strip().lower()
    location_id = (request.GET.get("location_id") or "").strip()
    data = _fetch_monitoring(role, location_id)
    return JsonResponse(data)
