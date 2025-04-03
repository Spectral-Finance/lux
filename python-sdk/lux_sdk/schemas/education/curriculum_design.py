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
            "timestamp": {"type": "string", "format": "date-time"},
            "curriculum_id": {"type": "string"},
            "title": {"type": "string"},
            "description": {"type": "string"},
            "subject_area": {"type": "string"},
            "educational_level": {
                "type": "object",
                "properties": {
                    "level": {"type": "string"},
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
                },
                "required": ["level"]
            },
            "learning_pathways": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "pathway_id": {"type": "string"},
                        "name": {"type": "string"},
                        "description": {"type": "string"},
                        "prerequisites": {"type": "array", "items": {"type": "string"}},
                        "learning_outcomes": {"type": "array", "items": {"type": "string"}},
                        "sequence": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "unit_id": {"type": "string"},
                                    "title": {"type": "string"},
                                    "duration": {"type": "string"},
                                    "objectives": {"type": "array", "items": {"type": "string"}}
                                },
                                "required": ["unit_id", "title", "duration", "objectives"]
                            }
                        }
                    },
                    "required": ["pathway_id", "name", "description", "learning_outcomes"]
                }
            },
            "course_structure": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "module_id": {"type": "string"},
                        "title": {"type": "string"},
                        "description": {"type": "string"},
                        "duration": {"type": "string"},
                        "learning_objectives": {"type": "array", "items": {"type": "string"}},
                        "topics": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "topic_id": {"type": "string"},
                                    "title": {"type": "string"},
                                    "content": {"type": "string"},
                                    "activities": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "activity_id": {"type": "string"},
                                                "type": {"type": "string"},
                                                "description": {"type": "string"},
                                                "duration": {"type": "string"},
                                                "resources": {"type": "array", "items": {"type": "string"}}
                                            },
                                            "required": ["activity_id", "type", "description"]
                                        }
                                    }
                                },
                                "required": ["topic_id", "title", "content"]
                            }
                        }
                    },
                    "required": ["module_id", "title", "description", "duration", "learning_objectives"]
                }
            },
            "assessment_strategy": {
                "type": "object",
                "properties": {
                    "formative_assessments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"},
                                "frequency": {"type": "string"},
                                "methods": {"type": "array", "items": {"type": "string"}},
                                "feedback_mechanism": {"type": "string"}
                            },
                            "required": ["type", "frequency", "methods", "feedback_mechanism"]
                        }
                    },
                    "summative_assessments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "assessment_id": {"type": "string"},
                                "type": {"type": "string"},
                                "weight": {"type": "number"},
                                "criteria": {"type": "array", "items": {"type": "string"}},
                                "rubric": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "criterion": {"type": "string"},
                                            "levels": {
                                                "type": "array",
                                                "items": {
                                                    "type": "object",
                                                    "properties": {
                                                        "level": {"type": "string"},
                                                        "description": {"type": "string"},
                                                        "score": {"type": "number"}
                                                    },
                                                    "required": ["level", "description", "score"]
                                                }
                                            }
                                        },
                                        "required": ["criterion"]
                                    }
                                }
                            },
                            "required": ["assessment_id", "type", "weight", "criteria"]
                        }
                    }
                }
            },
            "resources": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "resource_id": {"type": "string"},
                        "type": {"type": "string"},
                        "title": {"type": "string"},
                        "description": {"type": "string"},
                        "url": {"type": "string"},
                        "format": {"type": "string"},
                        "accessibility_features": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["resource_id", "type", "title", "description"]
                }
            },
            "differentiation_strategies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "learner_profile": {"type": "string"},
                        "adaptations": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string"},
                                    "description": {"type": "string"},
                                    "resources": {"type": "array", "items": {"type": "string"}}
                                },
                                "required": ["type", "description"]
                            }
                        }
                    },
                    "required": ["learner_profile"]
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
        },
        "required": ["timestamp", "curriculum_id", "title", "description", "subject_area", "educational_level", "learning_pathways", "course_structure", "assessment_strategy"]
    }
) 