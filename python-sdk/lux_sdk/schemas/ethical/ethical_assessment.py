"""
Ethical Assessment Schema

This schema represents ethical assessments and analyses, including principles,
stakeholder impacts, risks, and recommendations.
"""

from lux_sdk.signals import SignalSchema

EthicalAssessmentSchema = SignalSchema(
    name="ethical_assessment",
    version="1.0",
    description="Schema for ethical assessment and analysis of decisions, systems, or actions",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "assessment_id": {
                "type": "string",
                "description": "Unique identifier for this assessment"
            },
            "subject": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the subject being assessed"
                    },
                    "type": {
                        "type": "string",
                        "enum": ["decision", "system", "action", "policy", "technology", "other"],
                        "description": "Type of subject being assessed"
                    },
                    "description": {
                        "type": "string",
                        "description": "Detailed description of the subject"
                    },
                    "context": {
                        "type": "string",
                        "description": "Contextual information about the subject"
                    }
                },
                "required": ["name", "type", "description"]
            },
            "principles": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "principle_id": {
                            "type": "string",
                            "description": "Identifier for this principle"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the ethical principle"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the principle"
                        },
                        "relevance": {
                            "type": "string",
                            "description": "Why this principle is relevant"
                        },
                        "assessment": {
                            "type": "object",
                            "properties": {
                                "compliance_level": {
                                    "type": "string",
                                    "enum": ["compliant", "partially_compliant", "non_compliant", "unclear"],
                                    "description": "Level of compliance with principle"
                                },
                                "evidence": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Evidence supporting assessment"
                                    }
                                }
                            },
                            "required": ["compliance_level"]
                        }
                    },
                    "required": ["principle_id", "name", "description", "assessment"]
                }
            },
            "stakeholder_impact": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "stakeholder_id": {
                            "type": "string",
                            "description": "Identifier for this stakeholder group"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of stakeholder group"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of stakeholder group"
                        },
                        "impacts": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "enum": ["direct", "indirect", "short_term", "long_term"],
                                        "description": "Type of impact"
                                    },
                                    "description": {
                                        "type": "string",
                                        "description": "Description of the impact"
                                    },
                                    "severity": {
                                        "type": "string",
                                        "enum": ["low", "medium", "high", "critical"],
                                        "description": "Severity of the impact"
                                    },
                                    "likelihood": {
                                        "type": "string",
                                        "enum": ["unlikely", "possible", "likely", "very_likely"],
                                        "description": "Likelihood of the impact"
                                    }
                                },
                                "required": ["type", "description", "severity", "likelihood"]
                            }
                        },
                        "vulnerabilities": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Specific vulnerabilities of this group"
                            }
                        }
                    },
                    "required": ["stakeholder_id", "name", "impacts"]
                }
            },
            "risks": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "risk_id": {
                            "type": "string",
                            "description": "Identifier for this risk"
                        },
                        "category": {
                            "type": "string",
                            "enum": ["privacy", "fairness", "autonomy", "transparency", "safety", "other"],
                            "description": "Category of ethical risk"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the risk"
                        },
                        "severity": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"],
                            "description": "Severity of the risk"
                        },
                        "likelihood": {
                            "type": "string",
                            "enum": ["unlikely", "possible", "likely", "very_likely"],
                            "description": "Likelihood of the risk"
                        },
                        "mitigation_strategies": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "strategy": {
                                        "type": "string",
                                        "description": "Description of mitigation strategy"
                                    },
                                    "effectiveness": {
                                        "type": "string",
                                        "enum": ["low", "medium", "high"],
                                        "description": "Expected effectiveness"
                                    },
                                    "implementation_cost": {
                                        "type": "string",
                                        "enum": ["low", "medium", "high"],
                                        "description": "Cost of implementation"
                                    }
                                },
                                "required": ["strategy", "effectiveness"]
                            }
                        }
                    },
                    "required": ["risk_id", "category", "description", "severity", "likelihood"]
                }
            },
            "recommendations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "recommendation_id": {
                            "type": "string",
                            "description": "Identifier for this recommendation"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the recommendation"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"],
                            "description": "Priority level"
                        },
                        "implementation": {
                            "type": "object",
                            "properties": {
                                "steps": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Implementation steps"
                                    }
                                },
                                "timeline": {
                                    "type": "string",
                                    "description": "Expected implementation timeline"
                                },
                                "resources": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Required resources"
                                    }
                                }
                            }
                        }
                    },
                    "required": ["recommendation_id", "description", "priority"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "assessor": {
                        "type": "string",
                        "description": "ID of the assessor"
                    },
                    "assessment_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When assessment was performed"
                    },
                    "framework_used": {
                        "type": "string",
                        "description": "Ethical framework or guidelines used"
                    },
                    "review_status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "archived"],
                        "description": "Status of the assessment"
                    },
                    "next_review_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When assessment should be reviewed"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "assessment_id", "subject", "principles", "stakeholder_impact", "risks", "recommendations"]
    }
) 