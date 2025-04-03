"""
MedicalDiagnosisSchema

This schema represents medical diagnosis specifications, including
symptoms, diagnostic procedures, and treatment recommendations.
"""

from lux_sdk.signals import SignalSchema

MedicalDiagnosisSchema = SignalSchema(
    name="medical_diagnosis",
    version="1.0",
    description="Schema for representing medical diagnosis specifications and recommendations",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "diagnosis_id": {"type": "string", "required": True},
            "patient_id": {"type": "string", "required": True},
            "provider_id": {"type": "string", "required": True},
            "encounter_info": {
                "type": "object",
                "required": True,
                "properties": {
                    "date": {"type": "string", "format": "date-time", "required": True},
                    "type": {"type": "string", "enum": ["initial", "follow_up", "emergency", "routine"], "required": True},
                    "location": {"type": "string", "required": True},
                    "chief_complaint": {"type": "string", "required": True}
                }
            },
            "symptoms": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "description": {"type": "string", "required": True},
                        "severity": {"type": "string", "enum": ["mild", "moderate", "severe"], "required": True},
                        "onset": {"type": "string", "format": "date-time", "required": True},
                        "duration": {"type": "string"},
                        "frequency": {"type": "string"},
                        "location": {"type": "string"},
                        "characteristics": {"type": "array", "items": {"type": "string"}},
                        "aggravating_factors": {"type": "array", "items": {"type": "string"}},
                        "relieving_factors": {"type": "array", "items": {"type": "string"}}
                    }
                }
            },
            "physical_examination": {
                "type": "object",
                "required": True,
                "properties": {
                    "vital_signs": {
                        "type": "object",
                        "properties": {
                            "temperature": {
                                "type": "object",
                                "properties": {
                                    "value": {"type": "number", "required": True},
                                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"], "required": True}
                                }
                            },
                            "blood_pressure": {
                                "type": "object",
                                "properties": {
                                    "systolic": {"type": "integer", "required": True},
                                    "diastolic": {"type": "integer", "required": True},
                                    "unit": {"type": "string", "enum": ["mmHg"], "required": True}
                                }
                            },
                            "heart_rate": {"type": "integer", "required": True},
                            "respiratory_rate": {"type": "integer", "required": True},
                            "oxygen_saturation": {"type": "number", "minimum": 0, "maximum": 100}
                        }
                    },
                    "findings": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "system": {"type": "string", "required": True},
                                "observation": {"type": "string", "required": True},
                                "significance": {"type": "string", "enum": ["normal", "abnormal", "critical"], "required": True}
                            }
                        }
                    }
                }
            },
            "diagnostic_procedures": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "procedure": {"type": "string", "required": True},
                        "date": {"type": "string", "format": "date-time", "required": True},
                        "category": {"type": "string", "enum": ["laboratory", "imaging", "pathology", "other"], "required": True},
                        "results": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "parameter": {"type": "string", "required": True},
                                    "value": {"type": "string", "required": True},
                                    "unit": {"type": "string"},
                                    "reference_range": {"type": "string"},
                                    "interpretation": {"type": "string", "enum": ["normal", "abnormal", "critical"]}
                                }
                            }
                        },
                        "interpretation": {"type": "string", "required": True}
                    }
                }
            },
            "diagnoses": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "condition": {"type": "string", "required": True},
                        "icd_code": {"type": "string", "required": True},
                        "type": {"type": "string", "enum": ["primary", "secondary", "differential"], "required": True},
                        "certainty": {"type": "string", "enum": ["confirmed", "probable", "possible"], "required": True},
                        "stage": {"type": "string"},
                        "severity": {"type": "string", "enum": ["mild", "moderate", "severe"]},
                        "evidence": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string", "required": True},
                                    "description": {"type": "string", "required": True}
                                }
                            }
                        }
                    }
                }
            },
            "treatment_plan": {
                "type": "object",
                "properties": {
                    "medications": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "dosage": {"type": "string", "required": True},
                                "frequency": {"type": "string", "required": True},
                                "duration": {"type": "string", "required": True},
                                "route": {"type": "string", "required": True},
                                "instructions": {"type": "string"},
                                "precautions": {"type": "array", "items": {"type": "string"}}
                            }
                        }
                    },
                    "procedures": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "urgency": {"type": "string", "enum": ["emergency", "urgent", "elective"], "required": True},
                                "scheduled_date": {"type": "string", "format": "date-time"},
                                "preparation": {"type": "array", "items": {"type": "string"}},
                                "aftercare": {"type": "array", "items": {"type": "string"}}
                            }
                        }
                    },
                    "lifestyle_modifications": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "category": {"type": "string", "required": True},
                                "recommendations": {"type": "array", "items": {"type": "string"}, "required": True},
                                "goals": {"type": "array", "items": {"type": "string"}}
                            }
                        }
                    }
                }
            },
            "follow_up": {
                "type": "object",
                "properties": {
                    "timing": {"type": "string", "required": True},
                    "provider_type": {"type": "string", "required": True},
                    "instructions": {"type": "array", "items": {"type": "string"}},
                    "monitoring_parameters": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "parameter": {"type": "string", "required": True},
                                "frequency": {"type": "string", "required": True},
                                "target_values": {"type": "string"}
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {"type": "string"},
                    "creation_date": {"type": "string", "format": "date-time"},
                    "last_modified": {"type": "string", "format": "date-time"},
                    "status": {"type": "string", "enum": ["draft", "final", "amended", "cancelled"]},
                    "version": {"type": "string"},
                    "source_system": {"type": "string"},
                    "confidentiality": {"type": "string", "enum": ["normal", "restricted", "very_restricted"]}
                }
            }
        }
    }
) 