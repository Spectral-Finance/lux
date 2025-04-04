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
            "timestamp": {"type": "string", "format": "date-time"},
            "evaluation_id": {"type": "string"},
            "learner_id": {"type": "string"},
            "evaluator": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "role": {"type": "string"},
                    "qualifications": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["id", "name", "role"]
            },
            "evaluation_context": {
                "type": "object",
                "properties": {
                    "program": {"type": "string"},
                    "level": {"type": "string"},
                    "domain": {"type": "string"},
                    "date": {"type": "string", "format": "date-time"},
                    "setting": {"type": "string"}
                },
                "required": ["program", "level", "domain", "date", "setting"]
            },
            "skill_assessment": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "skill_id": {"type": "string"},
                        "name": {"type": "string"},
                        "category": {"type": "string"},
                        "description": {"type": "string"},
                        "proficiency_level": {
                            "type": "object",
                            "properties": {
                                "level": {"type": "string"},
                                "score": {"type": "number", "minimum": 0, "maximum": 100},
                                "descriptor": {"type": "string"}
                            },
                            "required": ["level", "score", "descriptor"]
                        },
                        "performance_indicators": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "indicator": {"type": "string"},
                                    "rating": {"type": "number"},
                                    "evidence": {"type": "array", "items": {"type": "string"}},
                                    "observations": {"type": "string"}
                                },
                                "required": ["indicator", "rating", "evidence"]
                            }
                        }
                    },
                    "required": ["skill_id", "name", "category", "description"]
                }
            },
            "competency_framework": {
                "type": "object",
                "properties": {
                    "framework_id": {"type": "string"},
                    "name": {"type": "string"},
                    "version": {"type": "string"},
                    "levels": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "level": {"type": "string"},
                                "description": {"type": "string"},
                                "criteria": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["level", "description", "criteria"]
                        }
                    }
                },
                "required": ["framework_id", "name", "version"]
            },
            "skill_progression": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "skill_id": {"type": "string"},
                        "previous_level": {"type": "string"},
                        "current_level": {"type": "string"},
                        "progress_metrics": {
                            "type": "object",
                            "properties": {
                                "improvement": {"type": "number"},
                                "time_spent": {"type": "number"},
                                "milestones_achieved": {"type": "integer"}
                            },
                            "required": ["improvement", "time_spent", "milestones_achieved"]
                        },
                        "learning_path": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "stage": {"type": "string"},
                                    "status": {"type": "string", "enum": ["completed", "in_progress", "planned"]},
                                    "completion_date": {"type": "string", "format": "date-time"}
                                },
                                "required": ["stage", "status"]
                            }
                        }
                    },
                    "required": ["skill_id", "previous_level", "current_level"]
                }
            },
            "practical_application": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "scenario_id": {"type": "string"},
                        "description": {"type": "string"},
                        "skills_demonstrated": {"type": "array", "items": {"type": "string"}},
                        "performance_rating": {"type": "number"},
                        "feedback": {"type": "string"},
                        "artifacts": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string"},
                                    "url": {"type": "string"},
                                    "description": {"type": "string"}
                                },
                                "required": ["type", "url"]
                            }
                        }
                    },
                    "required": ["scenario_id", "description", "skills_demonstrated", "performance_rating", "feedback"]
                }
            },
            "development_recommendations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "skill_id": {"type": "string"},
                        "focus_areas": {"type": "array", "items": {"type": "string"}},
                        "suggested_activities": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "activity": {"type": "string"},
                                    "description": {"type": "string"},
                                    "expected_outcomes": {"type": "array", "items": {"type": "string"}},
                                    "resources": {"type": "array", "items": {"type": "string"}}
                                },
                                "required": ["activity", "description", "expected_outcomes"]
                            }
                        }
                    },
                    "required": ["skill_id", "focus_areas"]
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
        },
        "required": ["timestamp", "evaluation_id", "learner_id", "evaluator", "evaluation_context", "skill_assessment", "competency_framework", "skill_progression", "development_recommendations"]
    }
) 