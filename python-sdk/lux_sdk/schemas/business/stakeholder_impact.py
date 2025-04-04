"""
Stakeholder Impact Schema

This schema represents stakeholder impact assessment and management,
including stakeholder analysis, impact evaluation, and engagement strategies.
"""

from lux_sdk.signals import SignalSchema

StakeholderImpactSchema = SignalSchema(
    name="stakeholder_impact",
    version="1.0",
    description="Schema for stakeholder impact assessment and management",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "assessment_id": {
                "type": "string",
                "description": "Unique identifier for this impact assessment"
            },
            "project_context": {
                "type": "object",
                "properties": {
                    "project_id": {
                        "type": "string",
                        "description": "Associated project identifier"
                    },
                    "project_name": {
                        "type": "string",
                        "description": "Name of the project"
                    },
                    "description": {
                        "type": "string",
                        "description": "Project description"
                    },
                    "scope": {
                        "type": "string",
                        "description": "Scope of impact assessment"
                    }
                },
                "required": ["project_id", "project_name"]
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
                        "name": {
                            "type": "string",
                            "description": "Name of stakeholder individual or group"
                        },
                        "category": {
                            "type": "string",
                            "enum": [
                                "internal",
                                "external",
                                "primary",
                                "secondary",
                                "key_decision_maker",
                                "influencer",
                                "affected_party"
                            ],
                            "description": "Category of stakeholder"
                        },
                        "role": {
                            "type": "string",
                            "description": "Role in relation to project"
                        },
                        "interests": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Key interests and concerns"
                        },
                        "influence_level": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Level of influence"
                        },
                        "impact_level": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Level of impact on stakeholder"
                        },
                        "current_sentiment": {
                            "type": "string",
                            "enum": ["positive", "neutral", "negative", "mixed"],
                            "description": "Current sentiment towards project"
                        }
                    },
                    "required": ["stakeholder_id", "name", "category"]
                }
            },
            "impact_assessment": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "impact_id": {
                            "type": "string",
                            "description": "Unique identifier for the impact"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the impact"
                        },
                        "type": {
                            "type": "string",
                            "enum": [
                                "economic",
                                "social",
                                "environmental",
                                "operational",
                                "strategic",
                                "regulatory"
                            ],
                            "description": "Type of impact"
                        },
                        "affected_stakeholders": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "IDs of affected stakeholders"
                        },
                        "magnitude": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Magnitude of impact"
                        },
                        "duration": {
                            "type": "string",
                            "enum": ["short_term", "medium_term", "long_term"],
                            "description": "Duration of impact"
                        },
                        "reversibility": {
                            "type": "string",
                            "enum": ["reversible", "partially_reversible", "irreversible"],
                            "description": "Whether impact can be reversed"
                        },
                        "mitigation_measures": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "measure_id": {
                                        "type": "string",
                                        "description": "Identifier for mitigation measure"
                                    },
                                    "description": {
                                        "type": "string",
                                        "description": "Description of measure"
                                    },
                                    "status": {
                                        "type": "string",
                                        "enum": ["planned", "in_progress", "completed"],
                                        "description": "Status of measure"
                                    }
                                }
                            }
                        }
                    },
                    "required": ["impact_id", "description", "type", "affected_stakeholders"]
                }
            },
            "engagement_strategy": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "strategy_id": {
                            "type": "string",
                            "description": "Unique identifier for strategy"
                        },
                        "stakeholder_id": {
                            "type": "string",
                            "description": "Target stakeholder"
                        },
                        "approach": {
                            "type": "string",
                            "enum": [
                                "inform",
                                "consult",
                                "involve",
                                "collaborate",
                                "empower"
                            ],
                            "description": "Engagement approach"
                        },
                        "communication_channels": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Preferred communication channels"
                        },
                        "frequency": {
                            "type": "string",
                            "description": "Frequency of engagement"
                        },
                        "key_messages": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Key messages for stakeholder"
                        },
                        "success_criteria": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Criteria for successful engagement"
                        }
                    },
                    "required": ["strategy_id", "stakeholder_id", "approach"]
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
                                    "description": "Identifier for metric"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Name of metric"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of metric"
                                },
                                "measurement_method": {
                                    "type": "string",
                                    "description": "How metric is measured"
                                },
                                "frequency": {
                                    "type": "string",
                                    "description": "Measurement frequency"
                                }
                            }
                        }
                    },
                    "review_schedule": {
                        "type": "object",
                        "properties": {
                            "frequency": {
                                "type": "string",
                                "description": "Review frequency"
                            },
                            "next_review": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Next scheduled review"
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "version": {
                        "type": "string",
                        "description": "Version of assessment"
                    },
                    "created_by": {
                        "type": "string",
                        "description": "Creator of assessment"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "archived"],
                        "description": "Current status"
                    },
                    "contributors": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "List of contributors"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "assessment_id",
            "project_context",
            "stakeholders",
            "impact_assessment"
        ]
    }
) 