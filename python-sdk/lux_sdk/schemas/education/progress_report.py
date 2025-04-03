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
            "timestamp": {"type": "string", "format": "date-time"},
            "report_id": {"type": "string"},
            "learner_id": {"type": "string"},
            "period": {
                "type": "object",
                "properties": {
                    "start_date": {"type": "string", "format": "date-time"},
                    "end_date": {"type": "string", "format": "date-time"},
                    "term": {"type": "string"}
                },
                "required": ["start_date", "end_date"]
            },
            "educational_context": {
                "type": "object",
                "properties": {
                    "program": {"type": "string"},
                    "level": {"type": "string"},
                    "institution": {"type": "string"},
                    "instructor": {"type": "string"}
                },
                "required": ["program", "level", "institution"]
            },
            "achievement_summary": {
                "type": "object",
                "properties": {
                    "overall_progress": {
                        "type": "object",
                        "properties": {
                            "percentage": {"type": "number", "minimum": 0, "maximum": 100},
                            "status": {"type": "string", "enum": ["ahead", "on_track", "behind"]},
                            "trend": {"type": "string", "enum": ["improving", "stable", "declining"]}
                        },
                        "required": ["percentage", "status", "trend"]
                    },
                    "completed_objectives": {"type": "integer"},
                    "total_objectives": {"type": "integer"},
                    "average_performance": {"type": "number"},
                    "strengths": {"type": "array", "items": {"type": "string"}},
                    "areas_for_improvement": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["completed_objectives", "total_objectives", "average_performance"]
            },
            "learning_objectives": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "objective_id": {"type": "string"},
                        "description": {"type": "string"},
                        "status": {"type": "string", "enum": ["not_started", "in_progress", "completed", "mastered"]},
                        "completion_date": {"type": "string", "format": "date-time"},
                        "proficiency_level": {"type": "string"},
                        "assessment_scores": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "assessment_id": {"type": "string"},
                                    "score": {"type": "number"},
                                    "date": {"type": "string", "format": "date-time"},
                                    "type": {"type": "string"}
                                },
                                "required": ["assessment_id", "score", "date", "type"]
                            }
                        }
                    },
                    "required": ["objective_id", "description", "status", "proficiency_level"]
                }
            },
            "skill_development": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "skill": {"type": "string"},
                        "current_level": {"type": "string"},
                        "target_level": {"type": "string"},
                        "progress": {"type": "number", "minimum": 0, "maximum": 100},
                        "evidence": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string"},
                                    "description": {"type": "string"},
                                    "date": {"type": "string", "format": "date-time"}
                                },
                                "required": ["type", "description", "date"]
                            }
                        }
                    },
                    "required": ["skill", "current_level", "target_level", "progress"]
                }
            },
            "engagement_metrics": {
                "type": "object",
                "properties": {
                    "attendance": {
                        "type": "object",
                        "properties": {
                            "present": {"type": "integer"},
                            "absent": {"type": "integer"},
                            "late": {"type": "integer"},
                            "percentage": {"type": "number"}
                        },
                        "required": ["present", "absent", "late", "percentage"]
                    },
                    "participation": {
                        "type": "object",
                        "properties": {
                            "level": {"type": "string"},
                            "activities_completed": {"type": "integer"},
                            "contributions": {"type": "integer"}
                        },
                        "required": ["level", "activities_completed", "contributions"]
                    },
                    "time_spent": {
                        "type": "object",
                        "properties": {
                            "total_hours": {"type": "number"},
                            "by_activity": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "activity_type": {"type": "string"},
                                        "hours": {"type": "number"}
                                    },
                                    "required": ["activity_type", "hours"]
                                }
                            }
                        },
                        "required": ["total_hours"]
                    }
                }
            },
            "recommendations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "area": {"type": "string"},
                        "suggestion": {"type": "string"},
                        "priority": {"type": "string", "enum": ["high", "medium", "low"]},
                        "resources": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["area", "suggestion", "priority"]
                }
            },
            "feedback": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string"},
                        "content": {"type": "string"},
                        "date": {"type": "string", "format": "date-time"},
                        "provider": {"type": "string"},
                        "action_items": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["type", "content", "date", "provider"]
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
        },
        "required": ["timestamp", "report_id", "learner_id", "period", "educational_context", "achievement_summary", "learning_objectives", "skill_development"]
    }
) 