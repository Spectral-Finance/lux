"""
AssessmentCriteriaSchema

This schema represents assessment criteria specifications, including
evaluation metrics, scoring rubrics, and performance indicators.
"""

from lux_sdk.signals import SignalSchema

AssessmentCriteriaSchema = SignalSchema(
    name="assessment_criteria",
    version="1.0",
    description="Schema for representing assessment criteria and evaluation metrics",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "criteria_id": {"type": "string", "required": True},
            "title": {"type": "string", "required": True},
            "description": {"type": "string", "required": True},
            "subject_area": {"type": "string", "required": True},
            "educational_level": {
                "type": "object",
                "required": True,
                "properties": {
                    "level": {"type": "string", "required": True},
                    "grade": {"type": "string"},
                    "age_range": {
                        "type": "object",
                        "properties": {
                            "min": {"type": "integer"},
                            "max": {"type": "integer"}
                        }
                    }
                }
            },
            "assessment_type": {
                "type": "string",
                "enum": ["formative", "summative", "diagnostic", "performance"],
                "required": True
            },
            "evaluation_criteria": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion_id": {"type": "string", "required": True},
                        "name": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "weight": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                        "performance_indicators": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "level": {"type": "string", "required": True},
                                    "description": {"type": "string", "required": True},
                                    "score_range": {
                                        "type": "object",
                                        "properties": {
                                            "min": {"type": "number", "required": True},
                                            "max": {"type": "number", "required": True}
                                        }
                                    },
                                    "examples": {"type": "array", "items": {"type": "string"}}
                                }
                            }
                        }
                    }
                }
            },
            "scoring_rubric": {
                "type": "object",
                "required": True,
                "properties": {
                    "total_points": {"type": "number", "required": True},
                    "passing_threshold": {"type": "number", "required": True},
                    "grading_scale": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "grade": {"type": "string", "required": True},
                                "min_score": {"type": "number", "required": True},
                                "max_score": {"type": "number", "required": True},
                                "description": {"type": "string", "required": True}
                            }
                        }
                    },
                    "rubric_criteria": {
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
                                            "points": {"type": "number", "required": True},
                                            "description": {"type": "string", "required": True},
                                            "indicators": {"type": "array", "items": {"type": "string"}}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "assessment_methods": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "method_id": {"type": "string", "required": True},
                        "name": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "tools": {"type": "array", "items": {"type": "string"}},
                        "data_collection": {
                            "type": "object",
                            "properties": {
                                "format": {"type": "string", "required": True},
                                "frequency": {"type": "string"},
                                "storage": {"type": "string"}
                            }
                        }
                    }
                }
            },
            "feedback_guidelines": {
                "type": "object",
                "properties": {
                    "timing": {"type": "string", "required": True},
                    "format": {"type": "string", "required": True},
                    "components": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "component": {"type": "string", "required": True},
                                "description": {"type": "string", "required": True},
                                "examples": {"type": "array", "items": {"type": "string"}}
                            }
                        }
                    }
                }
            },
            "accommodations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "eligibility_criteria": {"type": "array", "items": {"type": "string"}},
                        "implementation_guidelines": {"type": "string"}
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