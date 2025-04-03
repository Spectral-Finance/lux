"""
Healthcare Schemas

This module provides schemas for healthcare processes and monitoring,
including medical diagnosis, treatment planning, and patient care.
"""

from .medical_diagnosis import MedicalDiagnosisSchema
from .treatment_plan import TreatmentPlanSchema
from .patient_history import PatientHistorySchema
from .vital_signs import VitalSignsSchema
from .medication_schedule import MedicationScheduleSchema
from .symptom_report import SymptomReportSchema
from .lab_results import LabResultsSchema
from .care_instructions import CareInstructionsSchema
from .emergency_alert import EmergencyAlertSchema
from .wellness_metrics import WellnessMetricsSchema
from .preventive_care import PreventiveCareSchema

__all__ = [
    'MedicalDiagnosisSchema',
    'TreatmentPlanSchema',
    'PatientHistorySchema',
    'VitalSignsSchema',
    'MedicationScheduleSchema',
    'SymptomReportSchema',
    'LabResultsSchema',
    'CareInstructionsSchema',
    'EmergencyAlertSchema',
    'WellnessMetricsSchema',
    'PreventiveCareSchema'
] 