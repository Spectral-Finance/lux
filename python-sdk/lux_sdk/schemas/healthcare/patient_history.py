"""
PatientHistory Schema

This schema defines the structure for representing comprehensive patient medical histories,
including demographics, conditions, medications, procedures, and lifestyle information.
It helps healthcare providers maintain complete and accurate patient records while ensuring data privacy.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "history_id": "ph_20240320_153000",
    "patient_id": "pat_789",
    "demographics": {
        "date_of_birth": "1980-05-15",
        "gender": "female",
        "ethnicity": "hispanic",
        "race": "white",
        "language": ["english", "spanish"],
        "contact_info": {
            "phone": "+1-555-0123",
            "email": "patient@example.com"
        }
    },
    "medical_conditions": [{
        "condition_id": "cond_123",
        "name": "Type 2 Diabetes",
        "icd_code": "E11",
        "diagnosis_date": "2020-03-15",
        "status": "managed",
        "severity": "moderate",
        "progression": [{
            "date": "2024-02-15",
            "status": "stable",
            "notes": "HbA1c within target range"
        }]
    }]
}
```
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class PatientHistorySchema(SignalSchema):
    def __init__(self):
        super().__init__(
            name="patient_history",
            version="1.0",
            description="Schema for representing comprehensive patient medical histories",
            schema={
                "type": "object",
                "required": ["timestamp", "history_id", "patient_id", "demographics", "medical_conditions", "medications"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the history record was created"
                    },
                    "history_id": {
                        "type": "string",
                        "description": "Unique identifier for the history record"
                    },
                    "patient_id": {
                        "type": "string",
                        "description": "Identifier of the patient"
                    },
                    "demographics": {
                        "type": "object",
                        "description": "Patient demographic information",
                        "required": ["date_of_birth", "gender"],
                        "properties": {
                            "date_of_birth": {
                                "type": "string",
                                "format": "date",
                                "description": "Patient's date of birth"
                            },
                            "gender": {
                                "type": "string",
                                "enum": ["male", "female", "non-binary", "other", "prefer_not_to_say"],
                                "description": "Patient's gender"
                            },
                            "ethnicity": {
                                "type": "string",
                                "enum": ["hispanic", "non-hispanic", "unknown"],
                                "description": "Patient's ethnicity"
                            },
                            "race": {
                                "type": "string",
                                "enum": ["white", "black", "asian", "native_american", "pacific_islander", "other", "unknown"],
                                "description": "Patient's race"
                            },
                            "marital_status": {
                                "type": "string",
                                "enum": ["single", "married", "divorced", "widowed", "separated", "other"],
                                "description": "Marital status"
                            },
                            "occupation": {
                                "type": "string",
                                "description": "Current occupation"
                            },
                            "language": {
                                "type": "array",
                                "description": "Spoken languages",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "contact_info": {
                                "type": "object",
                                "description": "Contact information",
                                "properties": {
                                    "address": {
                                        "type": "string",
                                        "description": "Residential address"
                                    },
                                    "phone": {
                                        "type": "string",
                                        "pattern": "^\\+[1-9]\\d{1,14}$",
                                        "description": "Contact phone number in E.164 format"
                                    },
                                    "email": {
                                        "type": "string",
                                        "format": "email",
                                        "description": "Email address"
                                    }
                                }
                            }
                        }
                    },
                    "medical_conditions": {
                        "type": "array",
                        "description": "Medical conditions history",
                        "items": {
                            "type": "object",
                            "required": ["condition_id", "name", "diagnosis_date"],
                            "properties": {
                                "condition_id": {
                                    "type": "string",
                                    "description": "Condition identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Condition name"
                                },
                                "icd_code": {
                                    "type": "string",
                                    "pattern": "^[A-Z][0-9][0-9AB](\\.\\d{1,2})?$",
                                    "description": "ICD-10 code"
                                },
                                "diagnosis_date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Date of diagnosis"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["active", "resolved", "managed", "chronic", "acute", "in_remission"],
                                    "description": "Current status"
                                },
                                "severity": {
                                    "type": "string",
                                    "enum": ["mild", "moderate", "severe", "critical"],
                                    "description": "Condition severity"
                                },
                                "progression": {
                                    "type": "array",
                                    "description": "Condition progression",
                                    "items": {
                                        "type": "object",
                                        "required": ["date", "status"],
                                        "properties": {
                                            "date": {
                                                "type": "string",
                                                "format": "date",
                                                "description": "Assessment date"
                                            },
                                            "status": {
                                                "type": "string",
                                                "enum": ["improving", "stable", "worsening", "critical"],
                                                "description": "Status at assessment"
                                            },
                                            "notes": {
                                                "type": "string",
                                                "description": "Clinical notes"
                                            }
                                        }
                                    }
                                },
                                "treatments": {
                                    "type": "array",
                                    "description": "Associated treatments",
                                    "items": {
                                        "type": "string"
                                    }
                                }
                            }
                        }
                    },
                    "medications": {
                        "type": "array",
                        "description": "Medication history",
                        "items": {
                            "type": "object",
                            "required": ["medication_id", "name", "dosage", "start_date"],
                            "properties": {
                                "medication_id": {
                                    "type": "string",
                                    "description": "Medication identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Medication name"
                                },
                                "generic_name": {
                                    "type": "string",
                                    "description": "Generic name"
                                },
                                "dosage": {
                                    "type": "string",
                                    "description": "Dosage information"
                                },
                                "frequency": {
                                    "type": "string",
                                    "enum": ["once_daily", "twice_daily", "three_times_daily", "four_times_daily", "as_needed", "weekly", "monthly"],
                                    "description": "Administration frequency"
                                },
                                "start_date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Start date"
                                },
                                "end_date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "End date"
                                },
                                "prescriber": {
                                    "type": "string",
                                    "description": "Prescribing physician"
                                },
                                "reason": {
                                    "type": "string",
                                    "description": "Reason for prescription"
                                },
                                "side_effects": {
                                    "type": "array",
                                    "description": "Observed side effects",
                                    "items": {
                                        "type": "object",
                                        "required": ["effect", "severity", "onset_date"],
                                        "properties": {
                                            "effect": {
                                                "type": "string",
                                                "description": "Side effect description"
                                            },
                                            "severity": {
                                                "type": "string",
                                                "enum": ["mild", "moderate", "severe"],
                                                "description": "Effect severity"
                                            },
                                            "onset_date": {
                                                "type": "string",
                                                "format": "date",
                                                "description": "Onset date"
                                            }
                                        }
                                    }
                                },
                                "adherence": {
                                    "type": "object",
                                    "description": "Medication adherence",
                                    "properties": {
                                        "level": {
                                            "type": "string",
                                            "enum": ["high", "moderate", "low", "non_adherent"],
                                            "description": "Adherence level"
                                        },
                                        "issues": {
                                            "type": "array",
                                            "description": "Adherence issues",
                                            "items": {
                                                "type": "string"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "procedures": {
                        "type": "array",
                        "description": "Medical procedures history",
                        "items": {
                            "type": "object",
                            "required": ["procedure_id", "name", "date"],
                            "properties": {
                                "procedure_id": {
                                    "type": "string",
                                    "description": "Procedure identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Procedure name"
                                },
                                "cpt_code": {
                                    "type": "string",
                                    "pattern": "^\\d{5}$",
                                    "description": "CPT code"
                                },
                                "date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Procedure date"
                                },
                                "provider": {
                                    "type": "string",
                                    "description": "Healthcare provider"
                                },
                                "facility": {
                                    "type": "string",
                                    "description": "Medical facility"
                                },
                                "reason": {
                                    "type": "string",
                                    "description": "Reason for procedure"
                                },
                                "outcome": {
                                    "type": "string",
                                    "enum": ["successful", "partially_successful", "unsuccessful", "complications"],
                                    "description": "Procedure outcome"
                                },
                                "complications": {
                                    "type": "array",
                                    "description": "Complications if any",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "follow_up": {
                                    "type": "object",
                                    "description": "Follow-up care",
                                    "properties": {
                                        "required": {
                                            "type": "boolean",
                                            "description": "Follow-up needed"
                                        },
                                        "instructions": {
                                            "type": "string",
                                            "description": "Follow-up instructions"
                                        },
                                        "scheduled_date": {
                                            "type": "string",
                                            "format": "date",
                                            "description": "Scheduled follow-up date"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "allergies": {
                        "type": "array",
                        "description": "Allergy information",
                        "items": {
                            "type": "object",
                            "required": ["allergen", "severity"],
                            "properties": {
                                "allergen": {
                                    "type": "string",
                                    "description": "Allergen name"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["medication", "food", "environmental", "other"],
                                    "description": "Type of allergen"
                                },
                                "severity": {
                                    "type": "string",
                                    "enum": ["mild", "moderate", "severe", "life_threatening"],
                                    "description": "Reaction severity"
                                },
                                "reactions": {
                                    "type": "array",
                                    "description": "Observed reactions",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "diagnosis_date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Date of diagnosis"
                                },
                                "notes": {
                                    "type": "string",
                                    "description": "Additional notes"
                                }
                            }
                        }
                    },
                    "immunizations": {
                        "type": "array",
                        "description": "Immunization history",
                        "items": {
                            "type": "object",
                            "required": ["vaccine", "date"],
                            "properties": {
                                "vaccine": {
                                    "type": "string",
                                    "description": "Vaccine name"
                                },
                                "date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Administration date"
                                },
                                "administrator": {
                                    "type": "string",
                                    "description": "Healthcare provider"
                                },
                                "lot_number": {
                                    "type": "string",
                                    "description": "Vaccine lot number"
                                },
                                "site": {
                                    "type": "string",
                                    "enum": ["left_arm", "right_arm", "left_thigh", "right_thigh", "other"],
                                    "description": "Administration site"
                                },
                                "route": {
                                    "type": "string",
                                    "enum": ["intramuscular", "subcutaneous", "intradermal", "oral", "nasal"],
                                    "description": "Administration route"
                                },
                                "reactions": {
                                    "type": "array",
                                    "description": "Any reactions",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "next_due": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Next dose due date"
                                }
                            }
                        }
                    },
                    "family_history": {
                        "type": "array",
                        "description": "Family medical history",
                        "items": {
                            "type": "object",
                            "required": ["relation"],
                            "properties": {
                                "relation": {
                                    "type": "string",
                                    "enum": ["mother", "father", "sister", "brother", "grandmother", "grandfather", "aunt", "uncle", "cousin"],
                                    "description": "Family relation"
                                },
                                "conditions": {
                                    "type": "array",
                                    "description": "Medical conditions",
                                    "items": {
                                        "type": "object",
                                        "required": ["condition"],
                                        "properties": {
                                            "condition": {
                                                "type": "string",
                                                "description": "Condition name"
                                            },
                                            "age_of_onset": {
                                                "type": "integer",
                                                "minimum": 0,
                                                "maximum": 120,
                                                "description": "Age at onset"
                                            },
                                            "outcome": {
                                                "type": "string",
                                                "enum": ["recovered", "ongoing", "deceased", "unknown"],
                                                "description": "Condition outcome"
                                            }
                                        }
                                    }
                                },
                                "genetic_factors": {
                                    "type": "array",
                                    "description": "Genetic factors",
                                    "items": {
                                        "type": "string"
                                    }
                                }
                            }
                        }
                    },
                    "lifestyle": {
                        "type": "object",
                        "description": "Lifestyle information",
                        "properties": {
                            "smoking": {
                                "type": "object",
                                "description": "Smoking history",
                                "properties": {
                                    "status": {
                                        "type": "string",
                                        "enum": ["never", "former", "current", "passive"],
                                        "description": "Current status"
                                    },
                                    "packs_per_day": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 10,
                                        "description": "Packs per day"
                                    },
                                    "years": {
                                        "type": "integer",
                                        "minimum": 0,
                                        "maximum": 100,
                                        "description": "Years of smoking"
                                    }
                                }
                            },
                            "alcohol": {
                                "type": "object",
                                "description": "Alcohol consumption",
                                "properties": {
                                    "frequency": {
                                        "type": "string",
                                        "enum": ["never", "rarely", "occasionally", "weekly", "daily"],
                                        "description": "Consumption frequency"
                                    },
                                    "amount": {
                                        "type": "string",
                                        "description": "Typical amount"
                                    }
                                }
                            },
                            "exercise": {
                                "type": "object",
                                "description": "Exercise habits",
                                "properties": {
                                    "frequency": {
                                        "type": "string",
                                        "enum": ["never", "rarely", "1-2_times_weekly", "3-4_times_weekly", "5+_times_weekly", "daily"],
                                        "description": "Exercise frequency"
                                    },
                                    "type": {
                                        "type": "array",
                                        "description": "Types of exercise",
                                        "items": {
                                            "type": "string"
                                        }
                                    },
                                    "duration": {
                                        "type": "string",
                                        "description": "Typical duration"
                                    }
                                }
                            },
                            "diet": {
                                "type": "object",
                                "description": "Dietary habits",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "enum": ["omnivore", "vegetarian", "vegan", "pescatarian", "keto", "paleo", "other"],
                                        "description": "Diet type"
                                    },
                                    "restrictions": {
                                        "type": "array",
                                        "description": "Dietary restrictions",
                                        "items": {
                                            "type": "string"
                                        }
                                    },
                                    "supplements": {
                                        "type": "array",
                                        "description": "Dietary supplements",
                                        "items": {
                                            "type": "string"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the patient history",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Record creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Record version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "archived", "deleted"],
                                "description": "Record status"
                            },
                            "confidentiality": {
                                "type": "string",
                                "enum": ["public", "private", "restricted"],
                                "description": "Confidentiality level"
                            },
                            "access_history": {
                                "type": "array",
                                "description": "Record access history",
                                "items": {
                                    "type": "object",
                                    "required": ["accessor", "timestamp"],
                                    "properties": {
                                        "accessor": {
                                            "type": "string",
                                            "description": "Accessor identifier"
                                        },
                                        "timestamp": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Access timestamp"
                                        },
                                        "reason": {
                                            "type": "string",
                                            "description": "Access reason"
                                        }
                                    }
                                }
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    }
                }
            }
        ) 