"""
CurriculumDesignSchema

This schema represents curriculum design specifications, including
course structure, learning pathways, and assessment strategies.
"""

from lux_sdk.signals import SignalSchema

CurriculumDesignSchema = SignalSchema(
    name="curriculum_design",
    version="1.0",
    description="Schema for representing curriculum design specifications and learning pathways",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "curriculum_id": {"type": "string", "required": True},
            "title": {"type": "string", "required": True},
            "description": {"type": "string", "required": True},
            "subject_area": {"type": "string", "required": True},
            "educational_level": {
                "type": "object",
                "required": True,
                "properties": {
                    "level": {"type": "string", "required": True},
                    "grade_range": {
                        "type": "object",
                        "properties": {
                            "min": {"type": "string"},
                            "max": {"type": "string"}
                        }
                    },
                    "age_range": {
                        "type": "object",
                        "properties": {
                            "min": {"type": "integer"},
                            "max": {"type": "integer"}
                        }
                    }
                }
            },
            "learning_pathways": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "pathway_id": {"type": "string", "required": True},
                        "name": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "prerequisites": {"type": "array", "items": {"type": "string"}},
                        "learning_outcomes": {"type": "array", "items": {"type": "string"}, "required": True},
                        "sequence": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "unit_id": {"type": "string", "required": True},
                                    "title": {"type": "string", "required": True},
                                    "duration": {"type": "string", "required": True},
                                    "objectives": {"type": "array", "items": {"type": "string"}, "required": True}
                                }
                            }
                        }
                    }
                }
            },
            "course_structure": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "module_id": {"type": "string", "required": True},
                        "title": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "duration": {"type": "string", "required": True},
                        "learning_objectives": {"type": "array", "items": {"type": "string"}, "required": True},
                        "topics": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "topic_id": {"type": "string", "required": True},
                                    "title": {"type": "string", "required": True},
                                    "content": {"type": "string", "required": True},
                                    "activities": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "activity_id": {"type": "string", "required": True},
                                                "type": {"type": "string", "required": True},
                                                "description": {"type": "string", "required": True},
                                                "duration": {"type": "string"},
                                                "resources": {"type": "array", "items": {"type": "string"}}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "assessment_strategy": {
                "type": "object",
                "required": True,
                "properties": {
                    "formative_assessments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string", "required": True},
                                "frequency": {"type": "string", "required": True},
                                "methods": {"type": "array", "items": {"type": "string"}, "required": True},
                                "feedback_mechanism": {"type": "string", "required": True}
                            }
                        }
                    },
                    "summative_assessments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "assessment_id": {"type": "string", "required": True},
                                "type": {"type": "string", "required": True},
                                "weight": {"type": "number", "required": True},
                                "criteria": {"type": "array", "items": {"type": "string"}, "required": True},
                                "rubric": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "criterion": {"type": "string", "required": True},
                                            "levels": {
                                                "type": "array",
                                                "items": {
                                                    "type": "object",
                                                    "properties": {
                                                        "level": {"type": "string", "required": True},
                                                        "description": {"type": "string", "required": True},
                                                        "score": {"type": "number", "required": True}
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "resources": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "resource_id": {"type": "string", "required": True},
                        "type": {"type": "string", "required": True},
                        "title": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "url": {"type": "string"},
                        "format": {"type": "string"},
                        "accessibility_features": {"type": "array", "items": {"type": "string"}}
                    }
                }
            },
            "differentiation_strategies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "learner_profile": {"type": "string", "required": True},
                        "adaptations": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string", "required": True},
                                    "description": {"type": "string", "required": True},
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
                    "creator": {"type": "string"},
                    "creation_date": {"type": "string", "format": "date-time"},
                    "last_modified": {"type": "string", "format": "date-time"},
                    "status": {"type": "string", "enum": ["draft", "published", "archived", "under_review"]},
                    "version": {"type": "string"},
                    "standards_alignment": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "framework": {"type": "string"},
                                "code": {"type": "string"},
                                "description": {"type": "string"}
                            }
                        }
                    },
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "language": {"type": "string"},
                    "license": {"type": "string"}
                }
            }
        }
    }
) 