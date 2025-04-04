"""
Symptom Report Schema

This schema defines the structure for tracking patient symptoms,
including their characteristics, severity, and progression over time.
"""

from lux_sdk.signals import SignalSchema

SymptomReportSchema = SignalSchema(
    name="symptom_report",
    version="1.0",
    description="Schema for tracking patient symptoms and their characteristics",
    schema={
        "type": "object",
        "description": "Schema for patient symptom reports",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "When the symptom report was recorded"
            },
            "report_id": {
                "type": "string",
                "description": "Unique identifier for this symptom report"
            },
            "patient_id": {
                "type": "string",
                "description": "Identifier of the patient reporting symptoms"
            },
            "symptoms": {
                "type": "array",
                "description": "List of symptoms being reported",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "description": {"type": "string"},
                        "category": {
                            "type": "string",
                            "enum": [
                                "respiratory",
                                "cardiovascular",
                                "gastrointestinal",
                                "musculoskeletal",
                                "neurological",
                                "psychological",
                                "dermatological",
                                "general"
                            ]
                        },
                        "severity": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "enum": ["mild", "moderate", "severe", "critical"]
                                },
                                "score": {
                                    "type": "integer",
                                    "minimum": 0,
                                    "maximum": 10
                                },
                                "description": {"type": "string"}
                            },
                            "required": ["level", "score"]
                        },
                        "onset": {
                            "type": "object",
                            "properties": {
                                "date": {"type": "string", "format": "date"},
                                "type": {
                                    "type": "string",
                                    "enum": ["sudden", "gradual", "recurring"]
                                },
                                "trigger": {"type": "string"}
                            },
                            "required": ["date", "type"]
                        },
                        "duration": {
                            "type": "object",
                            "properties": {
                                "value": {"type": "number"},
                                "unit": {
                                    "type": "string",
                                    "enum": ["minutes", "hours", "days", "weeks", "months"]
                                },
                                "is_continuous": {"type": "boolean"}
                            },
                            "required": ["value", "unit"]
                        },
                        "frequency": {
                            "type": "object",
                            "properties": {
                                "times": {"type": "number"},
                                "period": {
                                    "type": "string",
                                    "enum": ["day", "week", "month"]
                                },
                                "pattern": {
                                    "type": "string",
                                    "enum": ["regular", "irregular", "increasing", "decreasing"]
                                }
                            },
                            "required": ["times", "period"]
                        }
                    },
                    "required": ["name", "category", "severity"]
                }
            },
            "associated_factors": {
                "type": "array",
                "description": "Factors that may be associated with the symptoms",
                "items": {
                    "type": "object",
                    "properties": {
                        "factor_type": {
                            "type": "string",
                            "enum": [
                                "medication",
                                "activity",
                                "food",
                                "environmental",
                                "stress",
                                "sleep",
                                "other"
                            ]
                        },
                        "description": {"type": "string"},
                        "relationship": {
                            "type": "string",
                            "enum": ["alleviates", "aggravates", "no_effect", "unknown"]
                        }
                    },
                    "required": ["factor_type", "relationship"]
                }
            },
            "impact_assessment": {
                "type": "object",
                "description": "Assessment of how symptoms impact daily life",
                "properties": {
                    "daily_activities": {
                        "type": "string",
                        "enum": ["none", "mild", "moderate", "severe", "complete"]
                    },
                    "work_ability": {
                        "type": "string",
                        "enum": ["unaffected", "slightly_affected", "moderately_affected", "severely_affected", "unable_to_work"]
                    },
                    "sleep_quality": {
                        "type": "string",
                        "enum": ["normal", "slightly_disturbed", "moderately_disturbed", "severely_disturbed", "unable_to_sleep"]
                    },
                    "social_interactions": {
                        "type": "string",
                        "enum": ["normal", "slightly_limited", "moderately_limited", "severely_limited", "no_interaction"]
                    }
                },
                "required": ["daily_activities", "work_ability"]
            },
            "current_treatments": {
                "type": "array",
                "description": "Current treatments being used for the symptoms",
                "items": {
                    "type": "object",
                    "properties": {
                        "treatment_type": {
                            "type": "string",
                            "enum": ["medication", "therapy", "lifestyle_change", "alternative_medicine", "none"]
                        },
                        "name": {"type": "string"},
                        "effectiveness": {
                            "type": "string",
                            "enum": ["not_effective", "slightly_effective", "moderately_effective", "very_effective", "unknown"]
                        },
                        "side_effects": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    },
                    "required": ["treatment_type", "effectiveness"]
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the symptom report",
                "properties": {
                    "reported_by": {
                        "type": "string",
                        "enum": ["patient", "caregiver", "healthcare_provider"]
                    },
                    "report_method": {
                        "type": "string",
                        "enum": ["in_person", "telehealth", "app", "phone", "email"]
                    },
                    "follow_up_required": {"type": "boolean"},
                    "follow_up_date": {"type": "string", "format": "date"},
                    "notes": {"type": "string"},
                    "attachments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"},
                                "url": {"type": "string"},
                                "description": {"type": "string"}
                            },
                            "required": ["type", "url"]
                        }
                    }
                },
                "required": ["reported_by", "report_method"]
            }
        },
        "required": [
            "timestamp",
            "report_id",
            "patient_id",
            "symptoms",
            "impact_assessment",
            "metadata"
        ]
    }) 