"""
SkillEvaluationSchema

This schema represents skill evaluation specifications, including
competency assessment, proficiency tracking, and skill development metrics.
"""

from lux_sdk.signals import SignalSchema

SkillEvaluationSchema = SignalSchema(
    name="skill_evaluation",
    version="1.0",
    description="Schema for representing skill evaluation and competency assessment",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "evaluation_id": {"type": "string", "required": True},
            "learner_id": {"type": "string", "required": True},
            "evaluator": {
                "type": "object",
                "required": True,
                "properties": {
                    "id": {"type": "string", "required": True},
                    "name": {"type": "string", "required": True},
                    "role": {"type": "string", "required": True},
                    "qualifications": {"type": "array", "items": {"type": "string"}}
                }
            },
            "evaluation_context": {
                "type": "object",
                "required": True,
                "properties": {
                    "program": {"type": "string", "required": True},
                    "level": {"type": "string", "required": True},
                    "domain": {"type": "string", "required": True},
                    "date": {"type": "string", "format": "date-time", "required": True},
                    "setting": {"type": "string", "required": True}
                }
            },
            "skill_assessment": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "skill_id": {"type": "string", "required": True},
                        "name": {"type": "string", "required": True},
                        "category": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "proficiency_level": {
                            "type": "object",
                            "properties": {
                                "level": {"type": "string", "required": True},
                                "score": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                                "descriptor": {"type": "string", "required": True}
                            }
                        },
                        "performance_indicators": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "indicator": {"type": "string", "required": True},
                                    "rating": {"type": "number", "required": True},
                                    "evidence": {"type": "array", "items": {"type": "string"}, "required": True},
                                    "observations": {"type": "string"}
                                }
                            }
                        }
                    }
                }
            },
            "competency_framework": {
                "type": "object",
                "required": True,
                "properties": {
                    "framework_id": {"type": "string", "required": True},
                    "name": {"type": "string", "required": True},
                    "version": {"type": "string", "required": True},
                    "levels": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "level": {"type": "string", "required": True},
                                "description": {"type": "string", "required": True},
                                "criteria": {"type": "array", "items": {"type": "string"}, "required": True}
                            }
                        }
                    }
                }
            },
            "skill_progression": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "skill_id": {"type": "string", "required": True},
                        "previous_level": {"type": "string", "required": True},
                        "current_level": {"type": "string", "required": True},
                        "progress_metrics": {
                            "type": "object",
                            "properties": {
                                "improvement": {"type": "number", "required": True},
                                "time_spent": {"type": "number", "required": True},
                                "milestones_achieved": {"type": "integer", "required": True}
                            }
                        },
                        "learning_path": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "stage": {"type": "string", "required": True},
                                    "status": {"type": "string", "enum": ["completed", "in_progress", "planned"], "required": True},
                                    "completion_date": {"type": "string", "format": "date-time"}
                                }
                            }
                        }
                    }
                }
            },
            "practical_application": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "scenario_id": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "skills_demonstrated": {"type": "array", "items": {"type": "string"}, "required": True},
                        "performance_rating": {"type": "number", "required": True},
                        "feedback": {"type": "string", "required": True},
                        "artifacts": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string", "required": True},
                                    "url": {"type": "string", "required": True},
                                    "description": {"type": "string"}
                                }
                            }
                        }
                    }
                }
            },
            "development_recommendations": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "skill_id": {"type": "string", "required": True},
                        "focus_areas": {"type": "array", "items": {"type": "string"}, "required": True},
                        "suggested_activities": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "activity": {"type": "string", "required": True},
                                    "description": {"type": "string", "required": True},
                                    "expected_outcomes": {"type": "array", "items": {"type": "string"}, "required": True},
                                    "resources": {"type": "array", "items": {"type": "string"}}
                                }
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "evaluation_method": {"type": "string"},
                    "evaluation_date": {"type": "string", "format": "date-time"},
                    "next_evaluation": {"type": "string", "format": "date-time"},
                    "version": {"type": "string"},
                    "confidentiality": {"type": "string"},
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "notes": {"type": "string"}
                }
            }
        }
    }
) 