"""
Strategy Plan Schema

This schema represents strategic planning and business strategy definition,
including objectives, initiatives, and performance metrics.
"""

from lux_sdk.signals import SignalSchema

StrategyPlanSchema = SignalSchema(
    name="strategy_plan",
    version="1.0",
    description="Schema for strategic planning and business strategy",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "plan_id": {
                "type": "string",
                "description": "Unique identifier for this strategy plan"
            },
            "name": {
                "type": "string",
                "description": "Name of the strategy plan"
            },
            "description": {
                "type": "string",
                "description": "Description of the strategy plan"
            },
            "time_horizon": {
                "type": "object",
                "properties": {
                    "start_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Start date of the strategy period"
                    },
                    "end_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "End date of the strategy period"
                    },
                    "planning_cycles": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "cycle_name": {
                                    "type": "string",
                                    "description": "Name of the planning cycle"
                                },
                                "duration": {
                                    "type": "string",
                                    "description": "Duration of the cycle"
                                },
                                "review_frequency": {
                                    "type": "string",
                                    "description": "Frequency of strategy review"
                                }
                            }
                        }
                    }
                },
                "required": ["start_date", "end_date"]
            },
            "vision_statement": {
                "type": "string",
                "description": "Organization's vision statement"
            },
            "mission_statement": {
                "type": "string",
                "description": "Organization's mission statement"
            },
            "strategic_objectives": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "objective_id": {
                            "type": "string",
                            "description": "Unique identifier for the objective"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the objective"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed description"
                        },
                        "category": {
                            "type": "string",
                            "enum": [
                                "financial",
                                "customer",
                                "internal_process",
                                "learning_growth",
                                "market_position",
                                "innovation",
                                "sustainability"
                            ],
                            "description": "Category of objective"
                        },
                        "target_outcomes": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "metric": {
                                        "type": "string",
                                        "description": "Performance metric"
                                    },
                                    "current_value": {
                                        "type": "number",
                                        "description": "Current value"
                                    },
                                    "target_value": {
                                        "type": "number",
                                        "description": "Target value"
                                    },
                                    "unit": {
                                        "type": "string",
                                        "description": "Unit of measurement"
                                    },
                                    "timeline": {
                                        "type": "string",
                                        "description": "Timeline for achievement"
                                    }
                                },
                                "required": ["metric", "target_value"]
                            }
                        }
                    },
                    "required": ["objective_id", "name", "category"]
                }
            },
            "strategic_initiatives": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "initiative_id": {
                            "type": "string",
                            "description": "Unique identifier for the initiative"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the initiative"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed description"
                        },
                        "objectives_supported": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Objectives supported by this initiative"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["critical", "high", "medium", "low"],
                            "description": "Priority level"
                        },
                        "timeline": {
                            "type": "object",
                            "properties": {
                                "start_date": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Start date"
                                },
                                "end_date": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "End date"
                                },
                                "milestones": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "name": {
                                                "type": "string",
                                                "description": "Milestone name"
                                            },
                                            "date": {
                                                "type": "string",
                                                "format": "date-time",
                                                "description": "Target date"
                                            }
                                        }
                                    }
                                }
                            }
                        },
                        "resource_requirements": {
                            "type": "object",
                            "properties": {
                                "budget": {
                                    "type": "number",
                                    "description": "Required budget"
                                },
                                "personnel": {
                                    "type": "number",
                                    "description": "Required personnel"
                                },
                                "technology": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Required technology"
                                }
                            }
                        }
                    },
                    "required": ["initiative_id", "name", "objectives_supported"]
                }
            },
            "market_analysis": {
                "type": "object",
                "properties": {
                    "target_markets": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "market_segment": {
                                    "type": "string",
                                    "description": "Market segment"
                                },
                                "size": {
                                    "type": "number",
                                    "description": "Market size"
                                },
                                "growth_rate": {
                                    "type": "number",
                                    "description": "Growth rate"
                                }
                            }
                        }
                    },
                    "competitive_analysis": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "competitor": {
                                    "type": "string",
                                    "description": "Competitor name"
                                },
                                "strengths": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "weaknesses": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "risk_assessment": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "risk_id": {
                            "type": "string",
                            "description": "Risk identifier"
                        },
                        "description": {
                            "type": "string",
                            "description": "Risk description"
                        },
                        "probability": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Probability of occurrence"
                        },
                        "impact": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Potential impact"
                        },
                        "mitigation_strategy": {
                            "type": "string",
                            "description": "Strategy to mitigate risk"
                        }
                    },
                    "required": ["risk_id", "description", "probability", "impact"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "version": {
                        "type": "string",
                        "description": "Version of the strategy plan"
                    },
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the plan"
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
                    "approvers": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "List of approvers"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "plan_id",
            "name",
            "time_horizon",
            "strategic_objectives",
            "strategic_initiatives"
        ]
    }
) 