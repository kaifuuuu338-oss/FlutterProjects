"""
SQLAlchemy database models for Problem B referral system.
"""
from sqlalchemy import Column, Integer, String, Date, DateTime, Text, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime, date

Base = declarative_base()


class Referral(Base):
    """Referral table - stores referral decisions and tracking."""
    __tablename__ = "referrals"

    referral_id = Column(Integer, primary_key=True, autoincrement=True)
    child_id = Column(String(100), nullable=False, index=True)
    
    # Risk assessment data
    risk_category = Column(String(50), nullable=False)  # LOW / MEDIUM / HIGH
    domains_delayed = Column(Integer, default=0)
    
    # Specific risk indicators
    autism_risk = Column(String(50))  # NONE / MODERATE / HIGH
    adhd_risk = Column(String(50))
    behavioral_risk = Column(String(50))
    nutrition_risk = Column(String(50))
    
    # Facility recommendation
    facility_type = Column(String(150))  # PHC / Block Pediatrician / District Specialist / DEIC
    urgency = Column(String(50))  # ROUTINE / PRIORITY / IMMEDIATE
    reason = Column(Text)  # WHY this facility chosen
    
    # Status tracking
    status = Column(String(50), default="PENDING")  # PENDING / SCHEDULED / COMPLETED / MISSED / ESCALATED
    appointment_date = Column(Date)
    completion_date = Column(Date)
    
    # Timeline
    referral_created_on = Column(Date, nullable=False, default=date.today)
    follow_up_deadline = Column(Date, nullable=False)
    
    # Escalation
    escalation_level = Column(Integer, default=0)
    escalated_to = Column(String(150))  # Block Medical Officer / District Health Officer / State ECD Officer
    
    # Override tracking
    system_recommended = Column(String(150))
    worker_selected = Column(String(150))
    override_reason = Column(Text)
    
    # Timestamps
    last_updated = Column(Date, default=date.today)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationship
    status_history = relationship("ReferralStatusHistory", back_populates="referral")

    def __repr__(self):
        return f"<Referral(id={self.referral_id}, child_id={self.child_id}, status={self.status})>"


class ReferralStatusHistory(Base):
    """Audit trail for all referral status changes."""
    __tablename__ = "referral_status_history"

    id = Column(Integer, primary_key=True, autoincrement=True)
    referral_id = Column(Integer, ForeignKey("referrals.referral_id"), nullable=False, index=True)
    
    old_status = Column(String(50))
    new_status = Column(String(50), nullable=False)
    
    changed_on = Column(Date, nullable=False, default=date.today)
    worker_id = Column(String(100))
    remarks = Column(Text)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationship
    referral = relationship("Referral", back_populates="status_history")

    def __repr__(self):
        return f"<ReferralStatusHistory(id={self.id}, referral_id={self.referral_id}, status={self.old_status}→{self.new_status})>"
