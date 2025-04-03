"""
Patient Record Schema

This schema represents patient health records and medical data, including
personal information, medical history, treatments, and healthcare providers.
"""

from lux_sdk.signals import SignalSchema

PatientRecordSchema = SignalSchema(
    name="patient_record",
    version="1.0",
    description="Schema for patient health records and medical data",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "record_id": {
                "type": "string",
                "description": "Unique identifier for this record"
            },
            "patient_info": {
                "type": "object",
                "properties": {
                    "patient_id": {
                        "type": "string",
                        "description": "Unique identifier for the patient"
                    },
                    "demographics": {
                        "type": "object",
                        "properties": {
                            "date_of_birth": {
                                "type": "string",
                                "format": "date",
                                "description": "Patient's date of birth"
                            },
                            "gender": {
                                "type": "string",
                                "description": "Patient's gender"
                            },
                            "ethnicity": {
                                "type": "string",
                                "description": "Patient's ethnicity"
                            },
                            "blood_type": {
                                "type": "string",
                                "enum": ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"],
                                "description": "Patient's blood type"
                            }
                        },
                        "required": ["date_of_birth", "gender"]
                    },
                    "contact_info": {
                        "type": "object",
                        "properties": {
                            "address": {
                                "type": "string",
                                "description": "Patient's address"
                            },
                            "phone": {
                                "type": "string",
                                "description": "Contact phone number"
                            },
                            "email": {
                                "type": "string",
                                "format": "email",
                                "description": "Contact email"
                            },
                            "emergency_contact": {
                                "type": "object",
                                "properties": {
                                    "name": {
                                        "type": "string",
                                        "description": "Emergency contact name"
                                    },
                                    "relationship": {
                                        "type": "string",
                                        "description": "Relationship to patient"
                                    },
                                    "phone": {
                                        "type": "string",
                                        "description": "Emergency contact phone"
                                    }
                                },
                                "required": ["name", "phone"]
                            }
                        }
                    }
                },
                "required": ["patient_id", "demographics"]
            },
            "medical_history": {
                "type": "object",
                "properties": {
                    "conditions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "condition_id": {
                                    "type": "string",
                                    "description": "Identifier for the condition"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Name of the condition"
                                },
                                "diagnosis_date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Date of diagnosis"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["active", "resolved", "chronic", "in_remission"],
                                    "description": "Current status"
                                },
                                "severity": {
                                    "type": "string",
                                    "enum": ["mild", "moderate", "severe"],
                                    "description": "Severity level"
                                }
                            },
                            "required": ["condition_id", "name", "diagnosis_date", "status"]
                        }
                    },
                    "allergies": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "allergen": {
                                    "type": "string",
                                    "description": "Allergen name"
                                },
                                "reaction": {
                                    "type": "string",
                                    "description": "Type of reaction"
                                },
                                "severity": {
                                    "type": "string",
                                    "enum": ["mild", "moderate", "severe"],
                                    "description": "Severity of reaction"
                                }
                            },
                            "required": ["allergen", "reaction"]
                        }
                    },
                    "surgeries": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "procedure": {
                                    "type": "string",
                                    "description": "Name of surgical procedure"
                                },
                                "date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Date of surgery"
                                },
                                "surgeon": {
                                    "type": "string",
                                    "description": "Surgeon name"
                                },
                                "facility": {
                                    "type": "string",
                                    "description": "Healthcare facility"
                                },
                                "outcome": {
                                    "type": "string",
                                    "description": "Procedure outcome"
                                }
                            },
                            "required": ["procedure", "date"]
                        }
                    },
                    "family_history": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "condition": {
                                    "type": "string",
                                    "description": "Medical condition"
                                },
                                "relation": {
                                    "type": "string",
                                    "description": "Family relationship"
                                },
                                "age_of_onset": {
                                    "type": "integer",
                                    "description": "Age when condition developed"
                                }
                            },
                            "required": ["condition", "relation"]
                        }
                    }
                }
            },
            "medications": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "medication_id": {
                            "type": "string",
                            "description": "Identifier for the medication"
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
                        "start_date": {
                            "type": "string",
                            "format": "date",
                            "description": "Start date of medication"
                        },
                        "end_date": {
                            "type": "string",
                            "format": "date",
                            "description": "End date of medication"
                        },
                        "prescriber": {
                            "type": "string",
                            "description": "Prescribing healthcare provider"
                        }
                    },
                    "required": ["medication_id", "name", "dosage", "frequency"]
                }
            },
            "vital_signs": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "timestamp": {
                            "type": "string",
                            "format": "date-time",
                            "description": "Time of measurement"
                        },
                        "blood_pressure": {
                            "type": "object",
                            "properties": {
                                "systolic": {
                                    "type": "integer",
                                    "description": "Systolic pressure"
                                },
                                "diastolic": {
                                    "type": "integer",
                                    "description": "Diastolic pressure"
                                }
                            }
                        },
                        "heart_rate": {
                            "type": "integer",
                            "description": "Heart rate in BPM"
                        },
                        "temperature": {
                            "type": "number",
                            "description": "Body temperature in Celsius"
                        },
                        "respiratory_rate": {
                            "type": "integer",
                            "description": "Breaths per minute"
                        },
                        "oxygen_saturation": {
                            "type": "number",
                            "description": "Blood oxygen saturation percentage"
                        }
                    },
                    "required": ["timestamp"]
                }
            },
            "immunizations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "vaccine": {
                            "type": "string",
                            "description": "Vaccine name"
                        },
                        "date": {
                            "type": "string",
                            "format": "date",
                            "description": "Date administered"
                        },
                        "administrator": {
                            "type": "string",
                            "description": "Healthcare provider"
                        },
                        "lot_number": {
                            "type": "string",
                            "description": "Vaccine lot number"
                        },
                        "next_due": {
                            "type": "string",
                            "format": "date",
                            "description": "Next dose due date"
                        }
                    },
                    "required": ["vaccine", "date"]
                }
            },
            "lab_results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "test_id": {
                            "type": "string",
                            "description": "Identifier for the test"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the test"
                        },
                        "date": {
                            "type": "string",
                            "format": "date-time",
                            "description": "Date and time of test"
                        },
                        "result": {
                            "type": "object",
                            "properties": {
                                "value": {
                                    "type": "string",
                                    "description": "Test result value"
                                },
                                "unit": {
                                    "type": "string",
                                    "description": "Unit of measurement"
                                },
                                "reference_range": {
                                    "type": "string",
                                    "description": "Normal range"
                                },
                                "interpretation": {
                                    "type": "string",
                                    "enum": ["normal", "abnormal", "critical"],
                                    "description": "Result interpretation"
                                }
                            },
                            "required": ["value"]
                        },
                        "ordering_provider": {
                            "type": "string",
                            "description": "Provider who ordered the test"
                        }
                    },
                    "required": ["test_id", "name", "date", "result"]
                }
            },
            "care_team": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "provider_id": {
                            "type": "string",
                            "description": "Provider identifier"
                        },
                        "name": {
                            "type": "string",
                            "description": "Provider name"
                        },
                        "role": {
                            "type": "string",
                            "description": "Healthcare role"
                        },
                        "specialty": {
                            "type": "string",
                            "description": "Medical specialty"
                        },
                        "contact_info": {
                            "type": "object",
                            "properties": {
                                "phone": {
                                    "type": "string",
                                    "description": "Contact phone"
                                },
                                "email": {
                                    "type": "string",
                                    "format": "email",
                                    "description": "Contact email"
                                }
                            }
                        }
                    },
                    "required": ["provider_id", "name", "role"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last record update"
                    },
                    "record_status": {
                        "type": "string",
                        "enum": ["active", "inactive", "archived"],
                        "description": "Status of the record"
                    },
                    "data_source": {
                        "type": "string",
                        "description": "Source of the record data"
                    },
                    "confidentiality": {
                        "type": "string",
                        "enum": ["normal", "restricted", "very_restricted"],
                        "description": "Confidentiality level"
                    }
                }
            }
        },
        "required": ["timestamp", "record_id", "patient_info"]
    }
) 