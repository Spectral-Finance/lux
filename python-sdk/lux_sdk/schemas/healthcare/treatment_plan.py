"""
Schema for medical treatment planning and management.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class TreatmentPlanSchema(SignalSchema):
    """Schema for representing medical treatment plans and interventions.
    
    This schema defines the structure for comprehensive medical treatment plans,
    including patient information, diagnoses, interventions, medications,
    monitoring plans, and follow-up care.
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "plan_id": "tp-123456",
            "patient_id": "pat-789",
            "patient_info": {
                "demographics": {
                    "age": 45,
                    "gender": "female",
                    "weight": 70.5,
                    "height": 165
                },
                "allergies": ["penicillin", "latex"],
                "chronic_conditions": ["hypertension"]
            },
            "diagnosis": {
                "primary_diagnosis": {
                    "condition": "Type 2 Diabetes",
                    "icd_code": "E11.9",
                    "date_diagnosed": "2024-01-15",
                    "severity": "moderate"
                },
                "secondary_diagnoses": [
                    {
                        "condition": "Hypertension",
                        "icd_code": "I10",
                        "relevance": "affects treatment options"
                    }
                ]
            },
            "treatment_objectives": [
                {
                    "objective_id": "obj-1",
                    "description": "Achieve glycemic control",
                    "priority": "high",
                    "target_outcome": "HbA1c < 7.0%",
                    "timeline": "3 months"
                }
            ],
            "interventions": [
                {
                    "intervention_id": "int-1",
                    "type": "medication",
                    "description": "Oral antidiabetic therapy",
                    "rationale": "First-line treatment",
                    "protocol": "Standard protocol",
                    "frequency": "daily",
                    "duration": "ongoing"
                }
            ],
            "medications": [
                {
                    "medication_id": "med-1",
                    "name": "Metformin",
                    "dosage": "500mg",
                    "frequency": "twice daily",
                    "route": "oral",
                    "duration": "3 months",
                    "special_instructions": "Take with meals"
                }
            ],
            "monitoring": {
                "vital_signs": [
                    {
                        "parameter": "blood_glucose",
                        "frequency": "twice daily",
                        "target_range": {
                            "min": 80,
                            "max": 130
                        },
                        "alert_thresholds": {
                            "low": 70,
                            "high": 200
                        }
                    }
                ],
                "lab_tests": [
                    {
                        "test_name": "HbA1c",
                        "frequency": "every 3 months",
                        "parameters": ["glycated hemoglobin"]
                    }
                ]
            },
            "lifestyle_modifications": [
                {
                    "category": "diet",
                    "description": "Low carbohydrate diet",
                    "rationale": "Improve glycemic control",
                    "goals": [
                        "Reduce refined carbohydrates",
                        "Increase fiber intake"
                    ]
                }
            ],
            "follow_up": {
                "schedule": [
                    {
                        "appointment_type": "endocrinologist",
                        "timing": "3 months",
                        "provider": "Dr. Smith",
                        "purpose": "Review medication efficacy"
                    }
                ],
                "criteria": {
                    "primary": "HbA1c improvement",
                    "secondary": "weight reduction"
                }
            },
            "metadata": {
                "created_at": "2024-04-03T12:34:56Z",
                "updated_at": "2024-04-03T12:34:56Z",
                "created_by": "dr-456",
                "reviewed_by": "dr-789",
                "version": "1.0",
                "status": "active",
                "tags": ["diabetes", "chronic_care"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="treatment_plan",
            version="1.0",
            description="Schema for representing medical treatment plans and interventions",
            schema={
                "type": "object",
                "required": ["timestamp", "plan_id", "patient_id", "patient_info", "diagnosis", "treatment_objectives", "interventions"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the treatment plan was created"
                    },
                    "plan_id": {
                        "type": "string",
                        "description": "Unique identifier for the treatment plan"
                    },
                    "patient_id": {
                        "type": "string",
                        "description": "Identifier of the patient"
                    },
                    "patient_info": {
                        "type": "object",
                        "required": ["demographics"],
                        "properties": {
                            "demographics": {
                                "type": "object",
                                "properties": {
                                    "age": {
                                        "type": "integer",
                                        "description": "Patient age"
                                    },
                                    "gender": {
                                        "type": "string",
                                        "description": "Patient gender"
                                    },
                                    "weight": {
                                        "type": "number",
                                        "description": "Patient weight in kg"
                                    },
                                    "height": {
                                        "type": "number",
                                        "description": "Patient height in cm"
                                    }
                                }
                            },
                            "allergies": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Known allergies"
                            },
                            "chronic_conditions": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Chronic conditions"
                            }
                        }
                    },
                    "diagnosis": {
                        "type": "object",
                        "required": ["primary_diagnosis"],
                        "properties": {
                            "primary_diagnosis": {
                                "type": "object",
                                "required": ["condition", "icd_code"],
                                "properties": {
                                    "condition": {
                                        "type": "string",
                                        "description": "Diagnosed condition"
                                    },
                                    "icd_code": {
                                        "type": "string",
                                        "description": "ICD-10 code"
                                    },
                                    "date_diagnosed": {
                                        "type": "string",
                                        "format": "date",
                                        "description": "Date of diagnosis"
                                    },
                                    "severity": {
                                        "type": "string",
                                        "description": "Condition severity"
                                    }
                                }
                            },
                            "secondary_diagnoses": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["condition", "icd_code"],
                                    "properties": {
                                        "condition": {
                                            "type": "string",
                                            "description": "Diagnosed condition"
                                        },
                                        "icd_code": {
                                            "type": "string",
                                            "description": "ICD-10 code"
                                        },
                                        "relevance": {
                                            "type": "string",
                                            "description": "Relevance to treatment"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "treatment_objectives": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["objective_id", "description", "priority"],
                            "properties": {
                                "objective_id": {
                                    "type": "string",
                                    "description": "Objective identifier"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of objective"
                                },
                                "priority": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high"],
                                    "description": "Priority level"
                                },
                                "target_outcome": {
                                    "type": "string",
                                    "description": "Expected outcome"
                                },
                                "timeline": {
                                    "type": "string",
                                    "description": "Timeline for achievement"
                                }
                            }
                        }
                    },
                    "interventions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["intervention_id", "type", "description"],
                            "properties": {
                                "intervention_id": {
                                    "type": "string",
                                    "description": "Intervention identifier"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Type of intervention"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of intervention"
                                },
                                "rationale": {
                                    "type": "string",
                                    "description": "Rationale for intervention"
                                },
                                "protocol": {
                                    "type": "string",
                                    "description": "Intervention protocol"
                                },
                                "frequency": {
                                    "type": "string",
                                    "description": "Frequency of intervention"
                                },
                                "duration": {
                                    "type": "string",
                                    "description": "Duration of intervention"
                                }
                            }
                        }
                    },
                    "medications": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["medication_id", "name", "dosage", "frequency"],
                            "properties": {
                                "medication_id": {
                                    "type": "string",
                                    "description": "Medication identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Medication name"
                                },
                                "dosage": {
                                    "type": "string",
                                    "description": "Dosage information"
                                },
                                "frequency": {
                                    "type": "string",
                                    "description": "Administration frequency"
                                },
                                "route": {
                                    "type": "string",
                                    "description": "Administration route"
                                },
                                "duration": {
                                    "type": "string",
                                    "description": "Duration of prescription"
                                },
                                "special_instructions": {
                                    "type": "string",
                                    "description": "Special instructions"
                                }
                            }
                        }
                    },
                    "monitoring": {
                        "type": "object",
                        "properties": {
                            "vital_signs": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["parameter", "frequency"],
                                    "properties": {
                                        "parameter": {
                                            "type": "string",
                                            "description": "Parameter to monitor"
                                        },
                                        "frequency": {
                                            "type": "string",
                                            "description": "Monitoring frequency"
                                        },
                                        "target_range": {
                                            "type": "object",
                                            "description": "Target range"
                                        },
                                        "alert_thresholds": {
                                            "type": "object",
                                            "description": "Alert thresholds"
                                        }
                                    }
                                }
                            },
                            "lab_tests": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["test_name", "frequency"],
                                    "properties": {
                                        "test_name": {
                                            "type": "string",
                                            "description": "Name of test"
                                        },
                                        "frequency": {
                                            "type": "string",
                                            "description": "Testing frequency"
                                        },
                                        "parameters": {
                                            "type": "array",
                                            "items": {
                                                "type": "string"
                                            },
                                            "description": "Test parameters"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "lifestyle_modifications": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["category", "description"],
                            "properties": {
                                "category": {
                                    "type": "string",
                                    "description": "Category of modification"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of change"
                                },
                                "rationale": {
                                    "type": "string",
                                    "description": "Rationale for change"
                                },
                                "goals": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Specific goals"
                                }
                            }
                        }
                    },
                    "follow_up": {
                        "type": "object",
                        "properties": {
                            "schedule": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["appointment_type", "timing"],
                                    "properties": {
                                        "appointment_type": {
                                            "type": "string",
                                            "description": "Type of appointment"
                                        },
                                        "timing": {
                                            "type": "string",
                                            "description": "Timing of appointment"
                                        },
                                        "provider": {
                                            "type": "string",
                                            "description": "Healthcare provider"
                                        },
                                        "purpose": {
                                            "type": "string",
                                            "description": "Purpose of follow-up"
                                        }
                                    }
                                }
                            },
                            "criteria": {
                                "type": "object",
                                "description": "Progress evaluation criteria"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "updated_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Plan creator"
                            },
                            "reviewed_by": {
                                "type": "string",
                                "description": "Plan reviewer"
                            },
                            "version": {
                                "type": "string",
                                "description": "Plan version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "completed", "discontinued"],
                                "description": "Plan status"
                            },
                            "tags": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Relevant tags"
                            }
                        }
                    }
                }
            }
        ) 