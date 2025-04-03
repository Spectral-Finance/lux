"""
Stakeholder Impact Schema

This schema represents the analysis and assessment of impacts on stakeholders,
including benefits, risks, and mitigation strategies.
"""

from lux_sdk.signals import SignalSchema

StakeholderImpactSchema = SignalSchema(
    name="stakeholder_impact",
    version="1.0",
    description="Schema for stakeholder impact analysis and assessment",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "analysis_id": {
                "type": "string",
                "description": "Unique identifier for this impact analysis"
            },
            "project_id": {
                "type": "string",
                "description": "Reference to the associated project"
            },
            "stakeholders": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "stakeholder_id": {
                            "type": "string",
                            "description": "Unique identifier for the stakeholder"
                        },
                        "category": {
                            "type": "string",
                            "enum": ["direct", "indirect", "primary", "secondary"],
                            "description": "Category of stakeholder"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the stakeholder group"
                        },
                        "size": {
                            "type": "integer",
                            "description": "Estimated size of stakeholder group"
                        },
                        "vulnerability_level": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Level of stakeholder vulnerability"
                        }
                    },
                    "required": ["stakeholder_id", "category", "description"]
                }
            },
            "impacts": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "impact_id": {
                            "type": "string",
                            "description": "Unique identifier for this impact"
                        },
                        "stakeholder_id": {
                            "type": "string",
                            "description": "Reference to affected stakeholder"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["economic", "social", "environmental", "health", "cultural", "other"],
                            "description": "Type of impact"
                        },
                        "nature": {
                            "type": "string",
                            "enum": ["positive", "negative", "mixed"],
                            "description": "Nature of the impact"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed description of the impact"
                        },
                        "severity": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "enum": ["critical", "high", "medium", "low"],
                                    "description": "Severity level of impact"
                                },
                                "justification": {
                                    "type": "string",
                                    "description": "Justification for severity rating"
                                }
                            },
                            "required": ["level"]
                        },
                        "likelihood": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "enum": ["very_likely", "likely", "possible", "unlikely", "very_unlikely"],
                                    "description": "Likelihood of impact occurring"
                                },
                                "confidence": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Confidence in likelihood assessment"
                                }
                            },
                            "required": ["level"]
                        }
                    },
                    "required": ["impact_id", "stakeholder_id", "type", "nature", "description"]
                }
            },
            "mitigation_strategies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "strategy_id": {
                            "type": "string",
                            "description": "Unique identifier for this strategy"
                        },
                        "impact_id": {
                            "type": "string",
                            "description": "Reference to the impact being mitigated"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the mitigation strategy"
                        },
                        "effectiveness": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Expected effectiveness of strategy"
                        },
                        "implementation_cost": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Cost of implementing strategy"
                        },
                        "timeline": {
                            "type": "object",
                            "properties": {
                                "start_date": {
                                    "type": "string",
                                    "format": "date-time"
                                },
                                "end_date": {
                                    "type": "string",
                                    "format": "date-time"
                                }
                            }
                        }
                    },
                    "required": ["strategy_id", "impact_id", "description"]
                }
            },
            "monitoring_plan": {
                "type": "object",
                "properties": {
                    "metrics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "metric_id": {
                                    "type": "string",
                                    "description": "Identifier for this metric"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Name of the metric"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of what is being measured"
                                },
                                "frequency": {
                                    "type": "string",
                                    "description": "How often metric is measured"
                                }
                            },
                            "required": ["metric_id", "name", "description"]
                        }
                    },
                    "review_schedule": {
                        "type": "object",
                        "properties": {
                            "frequency": {
                                "type": "string",
                                "description": "Frequency of impact reviews"
                            },
                            "next_review": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Date of next scheduled review"
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the impact analysis"
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
                        "description": "Version of the analysis"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "archived"],
                        "description": "Status of the analysis"
                    }
                }
            }
        },
        "required": ["timestamp", "analysis_id", "project_id", "stakeholders", "impacts"]
    }
) 