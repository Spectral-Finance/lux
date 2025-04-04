"""
Risk Assessment Schema

This schema represents risk assessment and management in business contexts,
including risk identification, analysis, evaluation, and mitigation strategies.
"""

from lux_sdk.signals import SignalSchema

RiskAssessmentSchema = SignalSchema(
    name="risk_assessment",
    version="1.0",
    description="Schema for risk assessment and management in business contexts",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "assessment_id": {
                "type": "string",
                "description": "Unique identifier for this risk assessment"
            },
            "name": {
                "type": "string",
                "description": "Name of the risk assessment"
            },
            "description": {
                "type": "string",
                "description": "Description of the assessment scope and objectives"
            },
            "context": {
                "type": "object",
                "properties": {
                    "business_unit": {
                        "type": "string",
                        "description": "Business unit being assessed"
                    },
                    "project": {
                        "type": "string",
                        "description": "Project or initiative being assessed"
                    },
                    "scope": {
                        "type": "string",
                        "enum": ["strategic", "operational", "financial", "compliance", "reputational"],
                        "description": "Scope of the assessment"
                    },
                    "stakeholders": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "stakeholder_id": {
                                    "type": "string",
                                    "description": "Stakeholder identifier"
                                },
                                "role": {
                                    "type": "string",
                                    "description": "Role in the assessment"
                                },
                                "impact_level": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high"],
                                    "description": "Level of impact on stakeholder"
                                }
                            },
                            "required": ["stakeholder_id", "role"]
                        }
                    }
                },
                "required": ["business_unit", "scope"]
            },
            "risks": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "risk_id": {
                            "type": "string",
                            "description": "Unique identifier for the risk"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the risk"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed description of the risk"
                        },
                        "category": {
                            "type": "string",
                            "enum": [
                                "strategic",
                                "operational",
                                "financial",
                                "compliance",
                                "technological",
                                "environmental",
                                "reputational",
                                "other"
                            ],
                            "description": "Category of risk"
                        },
                        "probability": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "enum": ["very_low", "low", "medium", "high", "very_high"],
                                    "description": "Probability level"
                                },
                                "score": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Numerical probability score"
                                },
                                "rationale": {
                                    "type": "string",
                                    "description": "Rationale for probability assessment"
                                }
                            },
                            "required": ["level"]
                        },
                        "impact": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "enum": ["negligible", "minor", "moderate", "major", "severe"],
                                    "description": "Impact level"
                                },
                                "score": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Numerical impact score"
                                },
                                "dimensions": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "dimension": {
                                                "type": "string",
                                                "description": "Impact dimension"
                                            },
                                            "description": {
                                                "type": "string",
                                                "description": "Impact description"
                                            },
                                            "severity": {
                                                "type": "string",
                                                "enum": ["low", "medium", "high"],
                                                "description": "Impact severity"
                                            }
                                        },
                                        "required": ["dimension", "severity"]
                                    }
                                }
                            },
                            "required": ["level"]
                        },
                        "risk_rating": {
                            "type": "object",
                            "properties": {
                                "inherent": {
                                    "type": "number",
                                    "description": "Inherent risk rating"
                                },
                                "residual": {
                                    "type": "number",
                                    "description": "Residual risk rating"
                                },
                                "tolerance": {
                                    "type": "number",
                                    "description": "Risk tolerance threshold"
                                }
                            },
                            "required": ["inherent"]
                        }
                    },
                    "required": ["risk_id", "name", "category", "probability", "impact"]
                }
            },
            "controls": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "control_id": {
                            "type": "string",
                            "description": "Unique identifier for the control"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the control"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["preventive", "detective", "corrective", "directive"],
                            "description": "Type of control"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the control"
                        },
                        "effectiveness": {
                            "type": "string",
                            "enum": ["low", "medium", "high"],
                            "description": "Control effectiveness"
                        },
                        "implementation_status": {
                            "type": "string",
                            "enum": ["planned", "in_progress", "implemented", "verified"],
                            "description": "Implementation status"
                        },
                        "cost": {
                            "type": "object",
                            "properties": {
                                "amount": {
                                    "type": "number",
                                    "description": "Cost amount"
                                },
                                "currency": {
                                    "type": "string",
                                    "description": "Currency code"
                                },
                                "frequency": {
                                    "type": "string",
                                    "description": "Cost frequency"
                                }
                            }
                        }
                    },
                    "required": ["control_id", "name", "type", "effectiveness"]
                }
            },
            "action_plan": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "action_id": {
                            "type": "string",
                            "description": "Unique identifier for the action"
                        },
                        "risk_id": {
                            "type": "string",
                            "description": "Associated risk ID"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the action"
                        },
                        "owner": {
                            "type": "string",
                            "description": "Action owner"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"],
                            "description": "Action priority"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["not_started", "in_progress", "completed", "cancelled"],
                            "description": "Action status"
                        },
                        "timeline": {
                            "type": "object",
                            "properties": {
                                "start_date": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Start date"
                                },
                                "due_date": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Due date"
                                }
                            }
                        }
                    },
                    "required": ["action_id", "risk_id", "description", "owner", "priority"]
                }
            },
            "monitoring": {
                "type": "object",
                "properties": {
                    "review_frequency": {
                        "type": "string",
                        "description": "Frequency of risk review"
                    },
                    "key_indicators": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "indicator_id": {
                                    "type": "string",
                                    "description": "Indicator identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Indicator name"
                                },
                                "threshold": {
                                    "type": "number",
                                    "description": "Alert threshold"
                                },
                                "current_value": {
                                    "type": "number",
                                    "description": "Current value"
                                }
                            },
                            "required": ["indicator_id", "name", "threshold"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "assessor": {
                        "type": "string",
                        "description": "Person conducting the assessment"
                    },
                    "assessment_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Date of assessment"
                    },
                    "next_review": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Next review date"
                    },
                    "version": {
                        "type": "string",
                        "description": "Assessment version"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "in_review", "approved", "archived"],
                        "description": "Assessment status"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "assessment_id",
            "name",
            "context",
            "risks"
        ]
    }
) 