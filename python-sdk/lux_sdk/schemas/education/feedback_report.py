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
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "report_id": {"type": "string", "required": True},
            "learner_id": {"type": "string", "required": True},
            "feedback_provider": {
                "type": "object",
                "required": True,
                "properties": {
                    "id": {"type": "string", "required": True},
                    "name": {"type": "string", "required": True},
                    "role": {"type": "string", "required": True},
                    "qualifications": {"type": "array", "items": {"type": "string"}}
                }
            },
            "feedback_context": {
                "type": "object",
                "required": True,
                "properties": {
                    "course": {"type": "string", "required": True},
                    "unit": {"type": "string", "required": True},
                    "activity": {"type": "string", "required": True},
                    "date": {"type": "string", "format": "date-time", "required": True},
                    "setting": {"type": "string", "required": True}
                }
            },
            "performance_assessment": {
                "type": "object",
                "required": True,
                "properties": {
                    "overall_rating": {
                        "type": "object",
                        "properties": {
                            "score": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                            "grade": {"type": "string", "required": True},
                            "descriptor": {"type": "string", "required": True}
                        }
                    },
                    "criteria_evaluation": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "criterion": {"type": "string", "required": True},
                                "rating": {"type": "number", "required": True},
                                "comments": {"type": "string", "required": True},
                                "evidence": {"type": "array", "items": {"type": "string"}}
                            }
                        }
                    }
                }
            },
            "strengths": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "area": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "examples": {"type": "array", "items": {"type": "string"}, "required": True},
                        "impact": {"type": "string", "required": True}
                    }
                }
            },
            "areas_for_improvement": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "area": {"type": "string", "required": True},
                        "current_level": {"type": "string", "required": True},
                        "target_level": {"type": "string", "required": True},
                        "gap_analysis": {"type": "string", "required": True},
                        "improvement_strategies": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "strategy": {"type": "string", "required": True},
                                    "description": {"type": "string", "required": True},
                                    "resources": {"type": "array", "items": {"type": "string"}},
                                    "timeline": {"type": "string"}
                                }
                            }
                        }
                    }
                }
            },
            "action_plan": {
                "type": "object",
                "required": True,
                "properties": {
                    "goals": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "goal_id": {"type": "string", "required": True},
                                "description": {"type": "string", "required": True},
                                "priority": {"type": "string", "enum": ["high", "medium", "low"], "required": True},
                                "timeline": {
                                    "type": "object",
                                    "properties": {
                                        "start_date": {"type": "string", "format": "date-time", "required": True},
                                        "target_date": {"type": "string", "format": "date-time", "required": True},
                                        "milestones": {
                                            "type": "array",
                                            "items": {
                                                "type": "object",
                                                "properties": {
                                                    "description": {"type": "string", "required": True},
                                                    "date": {"type": "string", "format": "date-time", "required": True}
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "support_resources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string", "required": True},
                                "name": {"type": "string", "required": True},
                                "description": {"type": "string", "required": True},
                                "access_information": {"type": "string"}
                            }
                        }
                    }
                }
            },
            "recommendations": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "rationale": {"type": "string", "required": True},
                        "expected_outcomes": {"type": "array", "items": {"type": "string"}, "required": True},
                        "implementation_steps": {"type": "array", "items": {"type": "string"}}
                    }
                }
            },
            "follow_up": {
                "type": "object",
                "properties": {
                    "next_review_date": {"type": "string", "format": "date-time", "required": True},
                    "monitoring_plan": {"type": "string", "required": True},
                    "success_criteria": {"type": "array", "items": {"type": "string"}, "required": True},
                    "support_contacts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "role": {"type": "string", "required": True},
                                "contact_info": {"type": "string", "required": True}
                            }
                        }
                    }
                }
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
        }
    }
) 