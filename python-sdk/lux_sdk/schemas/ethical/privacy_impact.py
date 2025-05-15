"""
Privacy Impact Schema

This schema represents the assessment of privacy impacts and risks,
including data handling practices, privacy controls, and compliance measures.
"""

from lux_sdk.signals import SignalSchema

PrivacyImpactSchema = SignalSchema(
    name="privacy_impact",
    version="1.0",
    description="Schema for privacy impact assessment and risk management",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "assessment_id": {
                "type": "string",
                "description": "Unique identifier for this privacy assessment"
            },
            "project_id": {
                "type": "string",
                "description": "Reference to the associated project"
            },
            "scope": {
                "type": "object",
                "properties": {
                    "system_name": {
                        "type": "string",
                        "description": "Name of the system being assessed"
                    },
                    "data_flows": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "List of data flows being assessed"
                    },
                    "jurisdiction": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Applicable legal jurisdictions"
                    }
                },
                "required": ["system_name"]
            },
            "data_inventory": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "data_category": {
                            "type": "string",
                            "enum": [
                                "personal_data",
                                "sensitive_personal_data",
                                "financial_data",
                                "health_data",
                                "biometric_data",
                                "location_data",
                                "communication_data",
                                "behavioral_data",
                                "other"
                            ],
                            "description": "Category of data being collected"
                        },
                        "purpose": {
                            "type": "string",
                            "description": "Purpose of data collection"
                        },
                        "retention_period": {
                            "type": "string",
                            "description": "How long the data will be retained"
                        },
                        "data_subjects": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Categories of individuals whose data is processed"
                        },
                        "legal_basis": {
                            "type": "string",
                            "enum": [
                                "consent",
                                "contract",
                                "legal_obligation",
                                "vital_interests",
                                "public_task",
                                "legitimate_interests"
                            ],
                            "description": "Legal basis for processing"
                        }
                    },
                    "required": ["data_category", "purpose", "retention_period"]
                }
            },
            "privacy_risks": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "risk_id": {
                            "type": "string",
                            "description": "Unique identifier for this risk"
                        },
                        "category": {
                            "type": "string",
                            "enum": [
                                "unauthorized_access",
                                "data_breach",
                                "data_loss",
                                "misuse",
                                "excessive_collection",
                                "inadequate_deletion",
                                "unauthorized_transfer",
                                "other"
                            ],
                            "description": "Category of privacy risk"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed description of the risk"
                        },
                        "affected_rights": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Privacy rights potentially affected"
                        },
                        "likelihood": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Likelihood of risk occurring"
                        },
                        "impact": {
                            "type": "string",
                            "enum": ["severe", "significant", "moderate", "minor"],
                            "description": "Potential impact if risk occurs"
                        }
                    },
                    "required": ["risk_id", "category", "description", "likelihood", "impact"]
                }
            },
            "controls_measures": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "control_id": {
                            "type": "string",
                            "description": "Unique identifier for this control"
                        },
                        "type": {
                            "type": "string",
                            "enum": [
                                "technical",
                                "organizational",
                                "legal",
                                "physical"
                            ],
                            "description": "Type of control measure"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the control measure"
                        },
                        "implementation_status": {
                            "type": "string",
                            "enum": ["implemented", "planned", "in_progress", "under_review"],
                            "description": "Status of control implementation"
                        },
                        "effectiveness": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Effectiveness of the control"
                        }
                    },
                    "required": ["control_id", "type", "description", "implementation_status"]
                }
            },
            "data_protection": {
                "type": "object",
                "properties": {
                    "encryption_methods": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Encryption methods used"
                    },
                    "access_controls": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "role": {
                                    "type": "string",
                                    "description": "Role or user group"
                                },
                                "permissions": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Permitted actions"
                                }
                            },
                            "required": ["role", "permissions"]
                        }
                    },
                    "data_minimization": {
                        "type": "string",
                        "description": "Measures for data minimization"
                    }
                }
            },
            "compliance": {
                "type": "object",
                "properties": {
                    "frameworks": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Applicable compliance frameworks"
                    },
                    "dpia_required": {
                        "type": "boolean",
                        "description": "Whether DPIA is required"
                    },
                    "legal_requirements": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "requirement": {
                                    "type": "string",
                                    "description": "Legal requirement"
                                },
                                "compliance_status": {
                                    "type": "string",
                                    "enum": ["compliant", "non_compliant", "partially_compliant", "not_applicable"],
                                    "description": "Status of compliance"
                                }
                            },
                            "required": ["requirement", "compliance_status"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the assessment"
                    },
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
                    "version": {
                        "type": "string",
                        "description": "Version of the assessment"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "archived"],
                        "description": "Status of the assessment"
                    },
                    "next_review_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Date for next review"
                    }
                }
            }
        },
        "required": ["timestamp", "assessment_id", "project_id", "scope", "data_inventory", "privacy_risks"]
    }
) 