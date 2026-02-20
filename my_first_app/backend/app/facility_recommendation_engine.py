"""
Problem B Facility Recommendation Engine.
Deterministic rule-based logic for recommending referral facility.
"""
from datetime import date, timedelta
from typing import Dict, Optional, Tuple


class FacilityRecommendation:
    """Data class for facility recommendation."""
    
    def __init__(self, facility: str, urgency: str, deadline_days: int, reason: str):
        self.facility = facility
        self.urgency = urgency
        self.deadline_days = deadline_days
        self.deadline = date.today() + timedelta(days=deadline_days)
        self.reason = reason
    
    def to_dict(self) -> Dict:
        return {
            "facility": self.facility,
            "urgency": self.urgency,
            "deadline": self.deadline.isoformat(),
            "deadline_days": self.deadline_days,
            "reason": self.reason
        }


class FacilityRecommendationEngine:
    """
    Implements Problem B facility recommendation logic.
    Strictly aligned to health system hierarchy and risk severity.
    """
    
    @staticmethod
    def recommend(
        risk_category: str,
        domains_delayed: int = 0,
        autism_risk: Optional[str] = None,
        adhd_risk: Optional[str] = None,
        behavioral_risk: Optional[str] = None,
        nutrition_risk: Optional[str] = None,
    ) -> Optional[FacilityRecommendation]:
        """
        Recommend facility based on risk profile.
        
        Args:
            risk_category: One of "LOW", "MEDIUM", "HIGH"
            domains_delayed: Number of developmental domains delayed
            autism_risk: One of "NONE", "MODERATE", "HIGH"
            adhd_risk: One of "NONE", "MODERATE", "HIGH"
            behavioral_risk: One of "NONE", "MODERATE", "HIGH"
            nutrition_risk: One of "NONE", "MODERATE", "SEVERE"
        
        Returns:
            FacilityRecommendation object or None if no referral needed
        """
        
        # Normalize inputs
        risk_category = (risk_category or "LOW").upper()
        domains_delayed = domains_delayed or 0
        autism_risk = (autism_risk or "NONE").upper()
        adhd_risk = (adhd_risk or "NONE").upper()
        behavioral_risk = (behavioral_risk or "NONE").upper()
        nutrition_risk = (nutrition_risk or "NONE").upper()
        
        # LOW RISK: No referral
        if risk_category == "LOW":
            return None
        
        # MEDIUM RISK: Conditional referral
        if risk_category == "MEDIUM":
            return FacilityRecommendationEngine._medium_risk_decision(
                domains_delayed, autism_risk, adhd_risk
            )
        
        # HIGH RISK: Always referral (complex logic)
        if risk_category == "HIGH":
            return FacilityRecommendationEngine._high_risk_decision(
                domains_delayed, autism_risk, adhd_risk, behavioral_risk, nutrition_risk
            )
        
        return None
    
    @staticmethod
    def _medium_risk_decision(
        domains_delayed: int,
        autism_risk: str,
        adhd_risk: str,
    ) -> Optional[FacilityRecommendation]:
        """Medium risk pathway - PRIoritize early screening."""
        
        # If clear neurodevelopmental concern
        if autism_risk == "MODERATE" or adhd_risk == "MODERATE" or domains_delayed >= 2:
            return FacilityRecommendation(
                facility="Primary Health Centre",
                urgency="ROUTINE",
                deadline_days=30,
                reason="Moderate developmental concern - early screening recommended"
            )
        
        # Otherwise, home intervention only
        return None
    
    @staticmethod
    def _high_risk_decision(
        domains_delayed: int,
        autism_risk: str,
        adhd_risk: str,
        behavioral_risk: str,
        nutrition_risk: str,
    ) -> FacilityRecommendation:
        """High risk pathway - comprehensive evaluation."""
        
        # Case 1: Neurodevelopmental disorders (priority)
        if autism_risk == "HIGH":
            return FacilityRecommendation(
                facility="District Specialist (Autism)",
                urgency="IMMEDIATE",
                deadline_days=2,
                reason="High autism risk - specialist evaluation immediate"
            )
        
        if adhd_risk == "HIGH":
            return FacilityRecommendation(
                facility="District Specialist (Behavioral)",
                urgency="IMMEDIATE",
                deadline_days=2,
                reason="High ADHD risk - specialist evaluation immediate"
            )
        
        # Case 2: Multiple domain delays
        if domains_delayed >= 3:
            return FacilityRecommendation(
                facility="District Early Intervention Centre (DEIC)",
                urgency="IMMEDIATE",
                deadline_days=2,
                reason=f"Global developmental delay ({domains_delayed} domains)"
            )
        
        # Case 3: Severe behavioral risk
        if behavioral_risk == "HIGH":
            return FacilityRecommendation(
                facility="Child Psychologist / District Mental Health Unit",
                urgency="IMMEDIATE",
                deadline_days=3,
                reason="Severe behavioral risk - mental health evaluation needed"
            )
        
        # Case 4: Nutrition crisis (stunting + developmental delay)
        if nutrition_risk == "SEVERE":
            return FacilityRecommendation(
                facility="Nutrition Rehabilitation Centre",
                urgency="PRIORITY",
                deadline_days=5,
                reason="Severe malnutrition with developmental impact"
            )
        
        # Case 5: Single domain high delay (fallback)
        return FacilityRecommendation(
            facility="Block Level Pediatrician",
            urgency="PRIORITY",
            deadline_days=7,
            reason="High-risk developmental delay - initial specialist evaluation"
        )
    
    @staticmethod
    def get_escalation_target(
        escalation_level: int,
        current_facility: Optional[str] = None,
    ) -> str:
        """
        Determine escalation target based on level and current facility.
        
        Args:
            escalation_level: Current escalation level (0, 1, 2+)
            current_facility: Current facility type
        
        Returns:
            String describing escalation target
        """
        
        # Default escalation chain
        escalation_chain = [
            "Block Medical Officer",
            "District Health Officer",
            "State ECD Officer"
        ]
        
        # If escalation based on facility level
        if current_facility:
            if "PHC" in current_facility or "Primary" in current_facility:
                facility_chain = [
                    "Block Medical Officer",
                    "District Health Officer",
                    "State ECD Officer"
                ]
            elif "Block" in current_facility:
                facility_chain = [
                    "District Health Officer",
                    "State ECD Officer",
                    "National Program Head"
                ]
            elif "District" in current_facility:
                facility_chain = [
                    "State ECD Officer",
                    "National Program Head",
                    "State Health Minister"
                ]
            else:
                facility_chain = escalation_chain
            
            return facility_chain[min(escalation_level, len(facility_chain) - 1)]
        
        # Default based on level
        return escalation_chain[min(escalation_level, len(escalation_chain) - 1)]
