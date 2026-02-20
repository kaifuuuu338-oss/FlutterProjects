"""
Problem B Referral Management API Endpoints.
Integrated into FastAPI application for referral lifecycle management.
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from datetime import date, datetime
from typing import Optional, List
from .database_models import Referral, ReferralStatusHistory, Base
from .referral_service import ReferralService
from .facility_recommendation_engine import FacilityRecommendationEngine
from .referral_db import get_db


# Create router
router = APIRouter(prefix="/api/referral", tags=["referral"])


# ============================================================================
# Pydantic Models (Request/Response Schemas)
# ============================================================================

class CreateReferralRequest(BaseModel):
    child_id: str
    risk_category: str  # LOW / MEDIUM / HIGH
    domains_delayed: int = 0
    autism_risk: Optional[str] = None
    adhd_risk: Optional[str] = None
    behavioral_risk: Optional[str] = None
    nutrition_risk: Optional[str] = None


class ReferralResponse(BaseModel):
    referral_id: int
    child_id: str
    risk_category: str
    facility_type: Optional[str]
    urgency: Optional[str]
    status: str
    reason: Optional[str]
    referral_created_on: str
    follow_up_deadline: str
    escalation_level: int
    escalated_to: Optional[str]
    system_recommended: Optional[str]
    worker_selected: Optional[str]


class UpdateStatusRequest(BaseModel):
    status: str  # SCHEDULED / COMPLETED / MISSED / ESCALATED
    appointment_date: Optional[date] = None
    worker_id: Optional[str] = None
    remarks: Optional[str] = None


class EscalateRequest(BaseModel):
    worker_id: Optional[str] = None


class OverrideFacilityRequest(BaseModel):
    new_facility: str
    override_reason: str
    worker_id: Optional[str] = None


class StatusHistoryResponse(BaseModel):
    id: int
    referral_id: int
    old_status: Optional[str]
    new_status: str
    changed_on: str
    worker_id: Optional[str]
    remarks: Optional[str]


# ============================================================================
# API Endpoints
# ============================================================================

@router.post("/create", response_model=ReferralResponse)
def create_referral(
    request: CreateReferralRequest,
    db: Session = Depends(get_db)
):
    """Create referral if needed based on risk profile."""
    try:
        referral = ReferralService.create_referral(
            db=db,
            child_id=request.child_id,
            risk_category=request.risk_category,
            domains_delayed=request.domains_delayed,
            autism_risk=request.autism_risk,
            adhd_risk=request.adhd_risk,
            behavioral_risk=request.behavioral_risk,
            nutrition_risk=request.nutrition_risk,
        )
        
        if referral is None:
            raise HTTPException(
                status_code=200,
                detail="No referral needed for this risk profile"
            )
        
        return ReferralResponse(
            referral_id=referral.referral_id,
            child_id=referral.child_id,
            risk_category=referral.risk_category,
            facility_type=referral.facility_type,
            urgency=referral.urgency,
            status=referral.status,
            reason=referral.reason,
            referral_created_on=referral.referral_created_on.isoformat(),
            follow_up_deadline=referral.follow_up_deadline.isoformat(),
            escalation_level=referral.escalation_level,
            escalated_to=referral.escalated_to,
            system_recommended=referral.system_recommended,
            worker_selected=referral.worker_selected,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{referral_id}", response_model=ReferralResponse)
def get_referral(referral_id: int, db: Session = Depends(get_db)):
    """Get referral by ID."""
    referral = ReferralService.get_referral(db, referral_id)
    if not referral:
        raise HTTPException(status_code=404, detail="Referral not found")
    
    return ReferralResponse(
        referral_id=referral.referral_id,
        child_id=referral.child_id,
        risk_category=referral.risk_category,
        facility_type=referral.facility_type,
        urgency=referral.urgency,
        status=referral.status,
        reason=referral.reason,
        referral_created_on=referral.referral_created_on.isoformat(),
        follow_up_deadline=referral.follow_up_deadline.isoformat(),
        escalation_level=referral.escalation_level,
        escalated_to=referral.escalated_to,
        system_recommended=referral.system_recommended,
        worker_selected=referral.worker_selected,
    )


@router.get("/child/{child_id}")
def get_active_referral_for_child(child_id: str, db: Session = Depends(get_db)):
    """Get active (non-completed) referral for a child."""
    referral = ReferralService.get_active_referral_by_child(db, child_id)
    if not referral:
        raise HTTPException(status_code=404, detail="No active referral found for child")
    
    return ReferralService.get_referral_dict(referral)


@router.put("/{referral_id}/status", response_model=ReferralResponse)
def update_referral_status(
    referral_id: int,
    request: UpdateStatusRequest,
    db: Session = Depends(get_db)
):
    """Update referral status."""
    try:
        referral = ReferralService.update_status(
            db=db,
            referral_id=referral_id,
            new_status=request.status,
            worker_id=request.worker_id,
            remarks=request.remarks,
            appointment_date=request.appointment_date,
        )
        
        return ReferralResponse(
            referral_id=referral.referral_id,
            child_id=referral.child_id,
            risk_category=referral.risk_category,
            facility_type=referral.facility_type,
            urgency=referral.urgency,
            status=referral.status,
            reason=referral.reason,
            referral_created_on=referral.referral_created_on.isoformat(),
            follow_up_deadline=referral.follow_up_deadline.isoformat(),
            escalation_level=referral.escalation_level,
            escalated_to=referral.escalated_to,
            system_recommended=referral.system_recommended,
            worker_selected=referral.worker_selected,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{referral_id}/escalate", response_model=ReferralResponse)
def escalate_referral(
    referral_id: int,
    request: EscalateRequest,
    db: Session = Depends(get_db)
):
    """Escalate referral to next level."""
    try:
        referral = ReferralService.escalate(
            db=db,
            referral_id=referral_id,
            worker_id=request.worker_id,
        )
        
        return ReferralResponse(
            referral_id=referral.referral_id,
            child_id=referral.child_id,
            risk_category=referral.risk_category,
            facility_type=referral.facility_type,
            urgency=referral.urgency,
            status=referral.status,
            reason=referral.reason,
            referral_created_on=referral.referral_created_on.isoformat(),
            follow_up_deadline=referral.follow_up_deadline.isoformat(),
            escalation_level=referral.escalation_level,
            escalated_to=referral.escalated_to,
            system_recommended=referral.system_recommended,
            worker_selected=referral.worker_selected,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{referral_id}/override-facility", response_model=ReferralResponse)
def override_facility(
    referral_id: int,
    request: OverrideFacilityRequest,
    db: Session = Depends(get_db)
):
    """Override system-recommended facility."""
    try:
        referral = ReferralService.override_facility(
            db=db,
            referral_id=referral_id,
            new_facility=request.new_facility,
            override_reason=request.override_reason,
            worker_id=request.worker_id,
        )
        
        return ReferralResponse(
            referral_id=referral.referral_id,
            child_id=referral.child_id,
            risk_category=referral.risk_category,
            facility_type=referral.facility_type,
            urgency=referral.urgency,
            status=referral.status,
            reason=referral.reason,
            referral_created_on=referral.referral_created_on.isoformat(),
            follow_up_deadline=referral.follow_up_deadline.isoformat(),
            escalation_level=referral.escalation_level,
            escalated_to=referral.escalated_to,
            system_recommended=referral.system_recommended,
            worker_selected=referral.worker_selected,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{referral_id}/history")
def get_referral_history(referral_id: int, db: Session = Depends(get_db)):
    """Get status history for a referral."""
    history = ReferralService.get_status_history(db, referral_id)
    
    return {
        "referral_id": referral_id,
        "history": [
            {
                "id": h.id,
                "old_status": h.old_status,
                "new_status": h.new_status,
                "changed_on": h.changed_on.isoformat(),
                "worker_id": h.worker_id,
                "remarks": h.remarks,
            }
            for h in history
        ]
    }
