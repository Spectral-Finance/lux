"""
Medication Schedule Schema

This schema defines the structure for medication schedules,
including dosage, timing, and administration instructions.
"""

from lux_sdk.signals import SignalSchema

MedicationScheduleSchema = SignalSchema(
    name="medication_schedule",
    version="1.0",
    description="Schema for medication schedules and administration details",
    schema={
        "type": "object",
        "description": "Schema for medication schedules and administration details",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the schedule was created or last modified"
            },
            "schedule_id": {
                "type": "string",
                "description": "Unique identifier for this medication schedule"
            },
            "patient_id": {
                "type": "string",
                "description": "Identifier of the patient"
            },
            "medications": {
                "type": "array",
                "description": "List of medications in the schedule",
                "items": {
                    "type": "object",
                    "properties": {
                        "medication_id": {"type": "string"},
                        "name": {"type": "string"},
                        "generic_name": {"type": "string"},
                        "strength": {
                            "type": "object",
                            "properties": {
                                "value": {"type": "number"},
                                "unit": {"type": "string"}
                            },
                            "required": ["value", "unit"]
                        },
                        "form": {
                            "type": "string",
                            "enum": [
                                "tablet",
                                "capsule",
                                "liquid",
                                "injection",
                                "patch",
                                "inhaler",
                                "cream",
                                "ointment",
                                "drops",
                                "other"
                            ]
                        },
                        "dosage": {
                            "type": "object",
                            "properties": {
                                "amount": {"type": "number"},
                                "unit": {"type": "string"},
                                "frequency": {
                                    "type": "object",
                                    "properties": {
                                        "times": {"type": "integer"},
                                        "period": {
                                            "type": "string",
                                            "enum": ["daily", "weekly", "monthly", "as_needed"]
                                        }
                                    },
                                    "required": ["times", "period"]
                                },
                                "timing": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "format": "time"
                                    }
                                }
                            },
                            "required": ["amount", "unit", "frequency"]
                        }
                    },
                    "required": ["medication_id", "name", "form", "dosage"]
                }
            },
            "administration_instructions": {
                "type": "array",
                "description": "Special instructions for medication administration",
                "items": {
                    "type": "object",
                    "properties": {
                        "medication_id": {"type": "string"},
                        "instructions": {"type": "string"},
                        "relation_to_meals": {
                            "type": "string",
                            "enum": ["before_meals", "with_meals", "after_meals", "independent_of_meals"]
                        },
                        "special_requirements": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    },
                    "required": ["medication_id", "instructions"]
                }
            },
            "duration": {
                "type": "object",
                "description": "Duration of the medication schedule",
                "properties": {
                    "start_date": {"type": "string", "format": "date"},
                    "end_date": {"type": "string", "format": "date"},
                    "is_indefinite": {"type": "boolean"}
                },
                "required": ["start_date"]
            },
            "precautions": {
                "type": "array",
                "description": "Precautions and warnings for the medications",
                "items": {
                    "type": "object",
                    "properties": {
                        "medication_id": {"type": "string"},
                        "warning_type": {
                            "type": "string",
                            "enum": ["allergy", "interaction", "side_effect", "contraindication"]
                        },
                        "description": {"type": "string"},
                        "severity": {
                            "type": "string",
                            "enum": ["mild", "moderate", "severe", "critical"]
                        }
                    },
                    "required": ["medication_id", "warning_type", "description"]
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the medication schedule",
                "properties": {
                    "prescriber": {"type": "string"},
                    "prescribed_date": {"type": "string", "format": "date"},
                    "last_reviewed": {"type": "string", "format": "date-time"},
                    "review_cycle": {
                        "type": "string",
                        "enum": ["weekly", "monthly", "quarterly", "annually"]
                    },
                    "version": {"type": "string"}
                },
                "required": ["prescriber", "prescribed_date"]
            }
        },
        "required": [
            "timestamp",
            "schedule_id",
            "patient_id",
            "medications",
            "duration",
            "metadata"
        ]
    })