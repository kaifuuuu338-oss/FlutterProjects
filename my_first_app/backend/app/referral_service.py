"""
Problem B Referral Management Service.
Handles referral lifecycle: creation, status updates, escalation, and audit trail.
"""
from datetime import datetime, date, timedelta
from typing import Optional, Dict, List
from sqlalchemy.orm import Session
from sqlalchemy import func

from .database_models import Referral, ReferralStatusHistory
from .facility_recommendation_engine import FacilityRecommendationEngine


class ReferralService:
    """Service for managing referral lifecycle."""
    
    @staticmethod
    def create_referral(
        db: Session,
        child_id: str,
        risk_category: str,
        domains_delayed: int = 0,
        autism_risk: Optional[str] = None,
        adhd_risk: Optional[str] = None,
        behavioral_risk: Optional[str] = None,
        nutrition_risk: Optional[str] = None,
    ) -> Optional[Referral]:
        """
        Create a referral for a child if needed based on risk profile.
        
        Returns:
            Referral object if created, None if not needed
        """
        
        # Get facility recommendation
        recommendation = FacilityRecommendationEngine.recommend(
            risk_category=risk_category,
            domains_delayed=domains_delayed,
            autism_risk=autism_risk,
            adhd_risk=adhd_risk,
            behavioral_risk=behavioral_risk,
            nutrition_risk=nutrition_risk,
        )
        
        # No referral needed
        if recommendation is None:
            return None
        
        # Check if referral already exists for this child
        existing = db.query(Referral).filter(
            Referral.child_id == child_id,
            Referral.status.in_(["PENDING", "SCHEDULED", "MISSED"])
        ).first()
        
        if existing:
            return existing
        
        # Create new referral
        referral = Referral(
            child_id=child_id,
            risk_category=risk_category,
            domains_delayed=domains_delayed,
            autism_risk=autism_risk,
            adhd_risk=adhd_risk,
            behavioral_risk=behavioral_risk,
            nutrition_risk=nutrition_risk,
            facility_type=recommendation.facility,
            urgency=recommendation.urgency,
            reason=recommendation.reason,
            status="PENDING",
            referral_created_on=date.today(),
            follow_up_deadline=recommendation.deadline,
            system_recommended=recommendation.facility,
            last_updated=date.today(),
        )
        
        db.add(referral)
        db.commit()
        db.refresh(referral)
        
        return referral
    
    @staticmethod
    def update_status(
        db: Session,
        referral_id: int,
        new_status: str,
        worker_id: Optional[str] = None,
        remarks: Optional[str] = None,
        appointment_date: Optional[date] = None,
    ) -> Referral:
        """
        Update referral status and create audit history.
        
        Valid transitions:
        - PENDING → SCHEDULED, MISSED
        - SCHEDULED → COMPLETED, MISSED
        - MISSED → SCHEDULED, ESCALATED
        """
        
        referral = db.query(Referral).filter(Referral.referral_id == referral_id).first()
        if not referral:
            raise ValueError(f"Referral {referral_id} not found")
        
        old_status = referral.status
        
        # Validate status transition
        valid_transitions = {
            "PENDING": ["SCHEDULED", "MISSED"],
            "SCHEDULED": ["COMPLETED", "MISSED"],
            "MISSED": ["SCHEDULED", "ESCALATED"],
            "COMPLETED": [],
            "ESCALATED": ["SCHEDULED", "COMPLETED"],
        }
        
        if new_status not in valid_transitions.get(old_status, []):
            raise ValueError(
                f"Invalid transition: {old_status} → {new_status}"
            )
        
        # Update referral
        referral.status = new_status
        referral.last_updated = date.today()
        
        # Status-specific updates
        if new_status == "SCHEDULED" and appointment_date:
            referral.appointment_date = appointment_date
        
        if new_status == "COMPLETED":
            referral.completion_date = date.today()
            referral.escalation_level = 0  # Reset escalation
        
        if new_status == "MISSED":
            # Escalate on miss
            referral.escalation_level += 1
            referral.follow_up_deadline = date.today() + timedelta(days=2)
        
        # Create history record
        history = ReferralStatusHistory(
            referral_id=referral_id,
            old_status=old_status,
            new_status=new_status,
            changed_on=date.today(),
            worker_id=worker_id,
            remarks=remarks,
        )
        
        db.add(history)
        db.commit()
        db.refresh(referral)
        
        return referral
    
    @staticmethod
    def escalate(
        db: Session,
        referral_id: int,
        worker_id: Optional[str] = None,
    ) -> Referral:
        """Escalate referral to next level."""
        
        referral = db.query(Referral).filter(Referral.referral_id == referral_id).first()
        if not referral:
            raise ValueError(f"Referral {referral_id} not found")
        
        # Escalate
        referral.escalation_level += 1
        referral.escalated_to = FacilityRecommendationEngine.get_escalation_target(
            referral.escalation_level,
            referral.facility_type
        )
        referral.status = "ESCALATED"
        referral.last_updated = date.today()
        
        # Create history record
        history = ReferralStatusHistory(
            referral_id=referral_id,
            old_status="MISSED",
            new_status="ESCALATED",
            changed_on=date.today(),
            worker_id=worker_id,
            remarks=f"Escalated to level {referral.escalation_level}: {referral.escalated_to}",
        )
        
        db.add(history)
        db.commit()
        db.refresh(referral)
        
        return referral
    
    @staticmethod
    def override_facility(
        db: Session,
        referral_id: int,
        new_facility: str,
        override_reason: str,
        worker_id: Optional[str] = None,
    ) -> Referral:
        """Allow worker to override system-recommended facility."""
        
        referral = db.query(Referral).filter(Referral.referral_id == referral_id).first()
        if not referral:
            raise ValueError(f"Referral {referral_id} not found")
        
        referral.worker_selected = new_facility
        referral.override_reason = override_reason
        referral.facility_type = new_facility
        referral.last_updated = date.today()
        
        # Create history record
        history = ReferralStatusHistory(
            referral_id=referral_id,
            old_status=referral.status,
            new_status=referral.status,
            changed_on=date.today(),
            worker_id=worker_id,
            remarks=f"Facility overridden from {referral.system_recommended} to {new_facility}. Reason: {override_reason}",
        )
        
        db.add(history)
        db.commit()
        db.refresh(referral)
        
        return referral
    
    @staticmethod
    def get_referral(db: Session, referral_id: int) -> Optional[Referral]:
        """Get referral by ID."""
        return db.query(Referral).filter(Referral.referral_id == referral_id).first()
    
    @staticmethod
    def get_referral_by_child(db: Session, child_id: str) -> List[Referral]:
        """Get all referrals for a child."""
        return db.query(Referral).filter(Referral.child_id == child_id).all()
    
    @staticmethod
    def get_active_referral_by_child(db: Session, child_id: str) -> Optional[Referral]:
        """Get active (non-completed) referral for a child."""
        return db.query(Referral).filter(
            Referral.child_id == child_id,
            Referral.status.in_(["PENDING", "SCHEDULED", "MISSED", "ESCALATED"])
        ).order_by(Referral.referral_created_on.desc()).first()
    
    @staticmethod
    def get_status_history(db: Session, referral_id: int) -> List[ReferralStatusHistory]:
        """Get audit trail for a referral."""
        return db.query(ReferralStatusHistory).filter(
            ReferralStatusHistory.referral_id == referral_id
        ).order_by(ReferralStatusHistory.changed_on.desc()).all()
    
    @staticmethod
    def auto_escalate_overdue(db: Session) -> List[Referral]:
        """
        Daily cron job: Auto-escalate referrals past deadline.
        Should be called daily by scheduler.
        """
        today = date.today()
        
        # Find overdue pending/scheduled referrals
        overdue = db.query(Referral).filter(
            Referral.follow_up_deadline <= today,
            Referral.status.in_(["PENDING", "SCHEDULED"]),
        ).all()
        
        escalated = []
        for referral in overdue:
            referral.escalation_level += 1
            referral.escalated_to = FacilityRecommendationEngine.get_escalation_target(
                referral.escalation_level,
                referral.facility_type
            )
            referral.status = "ESCALATED"
            referral.last_updated = today
            
            # Create history
            history = ReferralStatusHistory(
                referral_id=referral.referral_id,
                old_status="PENDING",
                new_status="ESCALATED",
                changed_on=today,
                remarks=f"Auto-escalated by system (deadline passed). Level {referral.escalation_level}",
            )
            
            db.add(history)
            escalated.append(referral)
        
        db.commit()
        return escalated
    
    @staticmethod
    def get_referral_dict(referral: Referral) -> Dict:
        """Convert referral to dictionary for JSON response."""
        return {
            "referral_id": referral.referral_id,
            "child_id": referral.child_id,
            "risk_category": referral.risk_category,
            "domains_delayed": referral.domains_delayed,
            "facility_type": referral.facility_type,
            "urgency": referral.urgency,
            "status": referral.status,
            "reason": referral.reason,
            "appointment_date": referral.appointment_date.isoformat() if referral.appointment_date else None,
            "completion_date": referral.completion_date.isoformat() if referral.completion_date else None,
            "referral_created_on": referral.referral_created_on.isoformat(),
            "follow_up_deadline": referral.follow_up_deadline.isoformat(),
            "escalation_level": referral.escalation_level,
            "escalated_to": referral.escalated_to,
            "system_recommended": referral.system_recommended,
            "worker_selected": referral.worker_selected,
            "override_reason": referral.override_reason,
            "last_updated": referral.last_updated.isoformat(),
        }
