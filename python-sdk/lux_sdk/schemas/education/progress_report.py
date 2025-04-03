"""
ProgressReportSchema

This schema represents learning progress report specifications, including
achievement tracking, milestone completion, and performance analysis.
"""

from lux_sdk.signals import SignalSchema

ProgressReportSchema = SignalSchema(
    name="progress_report",
    version="1.0",
    description="Schema for representing learning progress reports and achievement tracking",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "report_id": {"type": "string", "required": True},
            "learner_id": {"type": "string", "required": True},
            "period": {
                "type": "object",
                "required": True,
                "properties": {
                    "start_date": {"type": "string", "format": "date-time", "required": True},
                    "end_date": {"type": "string", "format": "date-time", "required": True},
                    "term": {"type": "string"}
                }
            },
            "educational_context": {
                "type": "object",
                "required": True,
                "properties": {
                    "program": {"type": "string", "required": True},
                    "level": {"type": "string", "required": True},
                    "institution": {"type": "string", "required": True},
                    "instructor": {"type": "string"}
                }
            },
            "achievement_summary": {
                "type": "object",
                "required": True,
                "properties": {
                    "overall_progress": {
                        "type": "object",
                        "properties": {
                            "percentage": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                            "status": {"type": "string", "enum": ["ahead", "on_track", "behind"], "required": True},
                            "trend": {"type": "string", "enum": ["improving", "stable", "declining"], "required": True}
                        }
                    },
                    "completed_objectives": {"type": "integer", "required": True},
                    "total_objectives": {"type": "integer", "required": True},
                    "average_performance": {"type": "number", "required": True},
                    "strengths": {"type": "array", "items": {"type": "string"}},
                    "areas_for_improvement": {"type": "array", "items": {"type": "string"}}
                }
            },
            "learning_objectives": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "objective_id": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "status": {"type": "string", "enum": ["not_started", "in_progress", "completed", "mastered"], "required": True},
                        "completion_date": {"type": "string", "format": "date-time"},
                        "proficiency_level": {"type": "string", "required": True},
                        "assessment_scores": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "assessment_id": {"type": "string", "required": True},
                                    "score": {"type": "number", "required": True},
                                    "date": {"type": "string", "format": "date-time", "required": True},
                                    "type": {"type": "string", "required": True}
                                }
                            }
                        }
                    }
                }
            },
            "skill_development": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "skill": {"type": "string", "required": True},
                        "current_level": {"type": "string", "required": True},
                        "target_level": {"type": "string", "required": True},
                        "progress": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                        "evidence": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string", "required": True},
                                    "description": {"type": "string", "required": True},
                                    "date": {"type": "string", "format": "date-time", "required": True}
                                }
                            }
                        }
                    }
                }
            },
            "engagement_metrics": {
                "type": "object",
                "properties": {
                    "attendance": {
                        "type": "object",
                        "properties": {
                            "present": {"type": "integer", "required": True},
                            "absent": {"type": "integer", "required": True},
                            "late": {"type": "integer", "required": True},
                            "percentage": {"type": "number", "required": True}
                        }
                    },
                    "participation": {
                        "type": "object",
                        "properties": {
                            "level": {"type": "string", "required": True},
                            "activities_completed": {"type": "integer", "required": True},
                            "contributions": {"type": "integer", "required": True}
                        }
                    },
                    "time_spent": {
                        "type": "object",
                        "properties": {
                            "total_hours": {"type": "number", "required": True},
                            "by_activity": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "activity_type": {"type": "string", "required": True},
                                        "hours": {"type": "number", "required": True}
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "recommendations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "area": {"type": "string", "required": True},
                        "suggestion": {"type": "string", "required": True},
                        "priority": {"type": "string", "enum": ["high", "medium", "low"], "required": True},
                        "resources": {"type": "array", "items": {"type": "string"}}
                    }
                }
            },
            "feedback": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string", "required": True},
                        "content": {"type": "string", "required": True},
                        "date": {"type": "string", "format": "date-time", "required": True},
                        "provider": {"type": "string", "required": True},
                        "action_items": {"type": "array", "items": {"type": "string"}}
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