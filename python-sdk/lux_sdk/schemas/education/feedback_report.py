"""
FeedbackReportSchema

This schema represents educational feedback report specifications, including
assessment feedback, improvement suggestions, and learning recommendations.
"""

from lux_sdk.signals import SignalSchema

FeedbackReportSchema = SignalSchema(
    name="feedback_report",
    version="1.0",
    description="Schema for representing educational feedback reports and learning recommendations",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time"},
            "report_id": {"type": "string"},
            "learner_id": {"type": "string"},
            "feedback_provider": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "role": {"type": "string"},
                    "qualifications": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["id", "name", "role"]
            },
            "feedback_context": {
                "type": "object",
                "properties": {
                    "course": {"type": "string"},
                    "unit": {"type": "string"},
                    "activity": {"type": "string"},
                    "date": {"type": "string", "format": "date-time"},
                    "setting": {"type": "string"}
                },
                "required": ["course", "unit", "activity", "date", "setting"]
            },
            "performance_assessment": {
                "type": "object",
                "properties": {
                    "overall_rating": {
                        "type": "object",
                        "properties": {
                            "score": {"type": "number", "minimum": 0, "maximum": 100},
                            "grade": {"type": "string"},
                            "descriptor": {"type": "string"}
                        },
                        "required": ["score", "grade", "descriptor"]
                    },
                    "criteria_evaluation": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "criterion": {"type": "string"},
                                "rating": {"type": "number"},
                                "comments": {"type": "string"},
                                "evidence": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["criterion", "rating", "comments"]
                        }
                    }
                }
            },
            "strengths": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "area": {"type": "string"},
                        "description": {"type": "string"},
                        "examples": {"type": "array", "items": {"type": "string"}},
                        "impact": {"type": "string"}
                    },
                    "required": ["area", "description", "examples", "impact"]
                }
            },
            "areas_for_improvement": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "area": {"type": "string"},
                        "current_level": {"type": "string"},
                        "target_level": {"type": "string"},
                        "gap_analysis": {"type": "string"},
                        "improvement_strategies": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "strategy": {"type": "string"},
                                    "description": {"type": "string"},
                                    "resources": {"type": "array", "items": {"type": "string"}},
                                    "timeline": {"type": "string"}
                                },
                                "required": ["strategy", "description"]
                            }
                        }
                    },
                    "required": ["area", "current_level", "target_level", "gap_analysis"]
                }
            },
            "action_plan": {
                "type": "object",
                "properties": {
                    "goals": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "goal_id": {"type": "string"},
                                "description": {"type": "string"},
                                "priority": {"type": "string", "enum": ["high", "medium", "low"]},
                                "timeline": {
                                    "type": "object",
                                    "properties": {
                                        "start_date": {"type": "string", "format": "date-time"},
                                        "target_date": {"type": "string", "format": "date-time"},
                                        "milestones": {
                                            "type": "array",
                                            "items": {
                                                "type": "object",
                                                "properties": {
                                                    "description": {"type": "string"},
                                                    "date": {"type": "string", "format": "date-time"}
                                                },
                                                "required": ["description", "date"]
                                            }
                                        }
                                    },
                                    "required": ["start_date", "target_date"]
                                }
                            },
                            "required": ["goal_id", "description", "priority", "timeline"]
                        }
                    },
                    "support_resources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"},
                                "name": {"type": "string"},
                                "description": {"type": "string"},
                                "access_information": {"type": "string"}
                            },
                            "required": ["type", "name", "description"]
                        }
                    }
                }
            },
            "recommendations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string"},
                        "description": {"type": "string"},
                        "rationale": {"type": "string"},
                        "expected_outcomes": {"type": "array", "items": {"type": "string"}},
                        "implementation_steps": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["type", "description", "rationale", "expected_outcomes"]
                }
            },
            "follow_up": {
                "type": "object",
                "properties": {
                    "next_review_date": {"type": "string", "format": "date-time"},
                    "monitoring_plan": {"type": "string"},
                    "success_criteria": {"type": "array", "items": {"type": "string"}},
                    "support_contacts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "role": {"type": "string"},
                                "contact_info": {"type": "string"}
                            },
                            "required": ["name", "role", "contact_info"]
                        }
                    }
                },
                "required": ["next_review_date", "monitoring_plan", "success_criteria"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "generated_by": {"type": "string"},
                    "generation_date": {"type": "string", "format": "date-time"},
                    "version": {"type": "string"},
                    "confidentiality": {"type": "string"},
                    "distribution_list": {"type": "array", "items": {"type": "string"}},
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "notes": {"type": "string"}
                }
            }
        },
        "required": ["timestamp", "report_id", "learner_id", "feedback_provider", "feedback_context", "performance_assessment", "strengths", "areas_for_improvement", "action_plan", "recommendations"]
    }
) 