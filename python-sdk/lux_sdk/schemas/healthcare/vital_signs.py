"""
Vital Signs Schema

This schema represents vital signs monitoring and health metrics,
including measurements, trends, and clinical assessments.
"""

from lux_sdk.signals import SignalSchema

VitalSignsSchema = SignalSchema(
    name="vital_signs",
    version="1.0",
    description="Schema for vital signs monitoring and health metrics",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "reading_id": {
                "type": "string",
                "description": "Unique identifier for this vital signs reading"
            },
            "patient_info": {
                "type": "object",
                "properties": {
                    "patient_id": {
                        "type": "string",
                        "description": "Patient identifier"
                    },
                    "age": {
                        "type": "number",
                        "description": "Patient age"
                    },
                    "gender": {
                        "type": "string",
                        "enum": ["male", "female", "other", "unknown"],
                        "description": "Patient gender"
                    },
                    "height": {
                        "type": "number",
                        "description": "Height in centimeters"
                    },
                    "weight": {
                        "type": "number",
                        "description": "Weight in kilograms"
                    },
                    "bmi": {
                        "type": "number",
                        "description": "Body Mass Index"
                    }
                },
                "required": ["patient_id"]
            },
            "vital_measurements": {
                "type": "object",
                "properties": {
                    "blood_pressure": {
                        "type": "object",
                        "properties": {
                            "systolic": {
                                "type": "number",
                                "description": "Systolic pressure in mmHg"
                            },
                            "diastolic": {
                                "type": "number",
                                "description": "Diastolic pressure in mmHg"
                            },
                            "mean_arterial": {
                                "type": "number",
                                "description": "Mean arterial pressure"
                            },
                            "position": {
                                "type": "string",
                                "enum": ["sitting", "standing", "supine"],
                                "description": "Position during measurement"
                            }
                        },
                        "required": ["systolic", "diastolic"]
                    },
                    "heart_rate": {
                        "type": "object",
                        "properties": {
                            "value": {
                                "type": "number",
                                "description": "Heart rate in beats per minute"
                            },
                            "regularity": {
                                "type": "string",
                                "enum": ["regular", "irregular"],
                                "description": "Heart rate regularity"
                            },
                            "quality": {
                                "type": "string",
                                "description": "Quality of measurement"
                            }
                        },
                        "required": ["value"]
                    },
                    "respiratory_rate": {
                        "type": "object",
                        "properties": {
                            "value": {
                                "type": "number",
                                "description": "Breaths per minute"
                            },
                            "effort": {
                                "type": "string",
                                "enum": ["normal", "increased", "labored"],
                                "description": "Breathing effort"
                            },
                            "pattern": {
                                "type": "string",
                                "description": "Breathing pattern"
                            }
                        },
                        "required": ["value"]
                    },
                    "temperature": {
                        "type": "object",
                        "properties": {
                            "value": {
                                "type": "number",
                                "description": "Temperature in Celsius"
                            },
                            "site": {
                                "type": "string",
                                "enum": ["oral", "tympanic", "axillary", "rectal"],
                                "description": "Measurement site"
                            },
                            "method": {
                                "type": "string",
                                "description": "Measurement method"
                            }
                        },
                        "required": ["value", "site"]
                    },
                    "oxygen_saturation": {
                        "type": "object",
                        "properties": {
                            "value": {
                                "type": "number",
                                "description": "SpO2 percentage"
                            },
                            "supplemental_oxygen": {
                                "type": "boolean",
                                "description": "Whether supplemental oxygen is in use"
                            },
                            "flow_rate": {
                                "type": "number",
                                "description": "Oxygen flow rate in L/min"
                            },
                            "delivery_method": {
                                "type": "string",
                                "description": "Oxygen delivery method"
                            }
                        },
                        "required": ["value"]
                    },
                    "pain_score": {
                        "type": "object",
                        "properties": {
                            "value": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 10,
                                "description": "Pain score (0-10)"
                            },
                            "scale": {
                                "type": "string",
                                "enum": ["numeric", "wong-baker", "flacc"],
                                "description": "Pain scale used"
                            },
                            "location": {
                                "type": "string",
                                "description": "Pain location"
                            },
                            "characteristics": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Pain characteristics"
                            }
                        },
                        "required": ["value", "scale"]
                    }
                }
            },
            "assessment": {
                "type": "object",
                "properties": {
                    "consciousness": {
                        "type": "string",
                        "enum": ["alert", "verbal", "pain", "unresponsive"],
                        "description": "Level of consciousness"
                    },
                    "early_warning_score": {
                        "type": "object",
                        "properties": {
                            "score": {
                                "type": "number",
                                "description": "Early warning score value"
                            },
                            "system": {
                                "type": "string",
                                "description": "Scoring system used"
                            },
                            "risk_level": {
                                "type": "string",
                                "enum": ["low", "medium", "high", "critical"],
                                "description": "Risk level"
                            }
                        }
                    },
                    "clinical_notes": {
                        "type": "string",
                        "description": "Additional clinical observations"
                    }
                }
            },
            "device_info": {
                "type": "object",
                "properties": {
                    "device_id": {
                        "type": "string",
                        "description": "Measuring device identifier"
                    },
                    "type": {
                        "type": "string",
                        "description": "Type of device"
                    },
                    "manufacturer": {
                        "type": "string",
                        "description": "Device manufacturer"
                    },
                    "model": {
                        "type": "string",
                        "description": "Device model"
                    },
                    "last_calibration": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last calibration date"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "recorded_by": {
                        "type": "string",
                        "description": "Healthcare provider recording vitals"
                    },
                    "facility": {
                        "type": "string",
                        "description": "Healthcare facility"
                    },
                    "department": {
                        "type": "string",
                        "description": "Department"
                    },
                    "encounter_id": {
                        "type": "string",
                        "description": "Associated encounter identifier"
                    },
                    "reason_for_measurement": {
                        "type": "string",
                        "description": "Reason for taking vitals"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "reading_id",
            "patient_info",
            "vital_measurements"
        ]
    }
) 