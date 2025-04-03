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
            "timestamp": {"type": "string", "format": "date-time"},
            "diagnosis_id": {"type": "string"},
            "patient_id": {"type": "string"},
            "provider_id": {"type": "string"},
            "encounter_info": {
                "type": "object",
                "properties": {
                    "date": {"type": "string", "format": "date-time"},
                    "type": {"type": "string", "enum": ["initial", "follow_up", "emergency", "routine"]},
                    "location": {"type": "string"},
                    "chief_complaint": {"type": "string"}
                },
                "required": ["date", "type", "location", "chief_complaint"]
            },
            "symptoms": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "description": {"type": "string"},
                        "severity": {"type": "string", "enum": ["mild", "moderate", "severe"]},
                        "onset": {"type": "string", "format": "date-time"},
                        "duration": {"type": "string"},
                        "frequency": {"type": "string"},
                        "location": {"type": "string"},
                        "characteristics": {"type": "array", "items": {"type": "string"}},
                        "aggravating_factors": {"type": "array", "items": {"type": "string"}},
                        "relieving_factors": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["description", "severity", "onset"]
                }
            },
            "physical_examination": {
                "type": "object",
                "properties": {
                    "vital_signs": {
                        "type": "object",
                        "properties": {
                            "temperature": {
                                "type": "object",
                                "properties": {
                                    "value": {"type": "number"},
                                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
                                },
                                "required": ["value", "unit"]
                            },
                            "blood_pressure": {
                                "type": "object",
                                "properties": {
                                    "systolic": {"type": "integer"},
                                    "diastolic": {"type": "integer"},
                                    "unit": {"type": "string", "enum": ["mmHg"]}
                                },
                                "required": ["systolic", "diastolic", "unit"]
                            },
                            "heart_rate": {"type": "integer"},
                            "respiratory_rate": {"type": "integer"},
                            "oxygen_saturation": {"type": "number", "minimum": 0, "maximum": 100}
                        },
                        "required": ["heart_rate", "respiratory_rate"]
                    },
                    "findings": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "system": {"type": "string"},
                                "observation": {"type": "string"},
                                "significance": {"type": "string", "enum": ["normal", "abnormal", "critical"]}
                            },
                            "required": ["system", "observation", "significance"]
                        }
                    }
                }
            },
            "diagnostic_procedures": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "procedure": {"type": "string"},
                        "date": {"type": "string", "format": "date-time"},
                        "category": {"type": "string", "enum": ["laboratory", "imaging", "pathology", "other"]},
                        "results": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "parameter": {"type": "string"},
                                    "value": {"type": "string"},
                                    "unit": {"type": "string"},
                                    "reference_range": {"type": "string"},
                                    "interpretation": {"type": "string", "enum": ["normal", "abnormal", "critical"]}
                                },
                                "required": ["parameter", "value"]
                            }
                        },
                        "interpretation": {"type": "string"}
                    },
                    "required": ["procedure", "date", "category", "interpretation"]
                }
            },
            "diagnoses": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "condition": {"type": "string"},
                        "icd_code": {"type": "string"},
                        "type": {"type": "string", "enum": ["primary", "secondary", "differential"]},
                        "certainty": {"type": "string", "enum": ["confirmed", "probable", "possible"]},
                        "stage": {"type": "string"},
                        "severity": {"type": "string", "enum": ["mild", "moderate", "severe"]},
                        "evidence": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string"},
                                    "description": {"type": "string"}
                                },
                                "required": ["type", "description"]
                            }
                        }
                    },
                    "required": ["condition", "icd_code", "type", "certainty"]
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
                                "name": {"type": "string"},
                                "dosage": {"type": "string"},
                                "frequency": {"type": "string"},
                                "duration": {"type": "string"},
                                "route": {"type": "string"},
                                "instructions": {"type": "string"},
                                "precautions": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["name", "dosage", "frequency", "duration", "route"]
                        }
                    },
                    "procedures": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "urgency": {"type": "string", "enum": ["emergency", "urgent", "elective"]},
                                "scheduled_date": {"type": "string", "format": "date-time"},
                                "preparation": {"type": "array", "items": {"type": "string"}},
                                "aftercare": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["name", "urgency"]
                        }
                    },
                    "lifestyle_modifications": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "category": {"type": "string"},
                                "recommendations": {"type": "array", "items": {"type": "string"}},
                                "goals": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["category", "recommendations"]
                        }
                    }
                }
            },
            "follow_up": {
                "type": "object",
                "properties": {
                    "timing": {"type": "string"},
                    "provider_type": {"type": "string"},
                    "instructions": {"type": "array", "items": {"type": "string"}},
                    "monitoring_parameters": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "parameter": {"type": "string"},
                                "frequency": {"type": "string"},
                                "target_values": {"type": "string"}
                            },
                            "required": ["parameter", "frequency"]
                        }
                    }
                },
                "required": ["timing", "provider_type"]
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
        },
        "required": ["timestamp", "diagnosis_id", "patient_id", "provider_id", "encounter_info", "symptoms", "physical_examination", "diagnoses"]
    }
) 