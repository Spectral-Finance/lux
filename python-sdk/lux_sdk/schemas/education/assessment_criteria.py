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
            "timestamp": {"type": "string", "format": "date-time"},
            "criteria_id": {"type": "string"},
            "title": {"type": "string"},
            "description": {"type": "string"},
            "subject_area": {"type": "string"},
            "educational_level": {
                "type": "object",
                "properties": {
                    "level": {"type": "string"},
                    "grade": {"type": "string"},
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
            "assessment_type": {
                "type": "string",
                "enum": ["formative", "summative", "diagnostic", "performance"]
            },
            "evaluation_criteria": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion_id": {"type": "string"},
                        "name": {"type": "string"},
                        "description": {"type": "string"},
                        "weight": {"type": "number", "minimum": 0, "maximum": 100},
                        "performance_indicators": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "level": {"type": "string"},
                                    "description": {"type": "string"},
                                    "score_range": {
                                        "type": "object",
                                        "properties": {
                                            "min": {"type": "number"},
                                            "max": {"type": "number"}
                                        },
                                        "required": ["min", "max"]
                                    },
                                    "examples": {"type": "array", "items": {"type": "string"}}
                                },
                                "required": ["level", "description"]
                            }
                        }
                    },
                    "required": ["criterion_id", "name", "description", "weight"]
                }
            },
            "scoring_rubric": {
                "type": "object",
                "properties": {
                    "total_points": {"type": "number"},
                    "passing_threshold": {"type": "number"},
                    "grading_scale": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "grade": {"type": "string"},
                                "min_score": {"type": "number"},
                                "max_score": {"type": "number"},
                                "description": {"type": "string"}
                            },
                            "required": ["grade", "min_score", "max_score", "description"]
                        }
                    },
                    "rubric_criteria": {
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
                                            "points": {"type": "number"},
                                            "description": {"type": "string"},
                                            "indicators": {"type": "array", "items": {"type": "string"}}
                                        },
                                        "required": ["level", "points", "description"]
                                    }
                                }
                            },
                            "required": ["criterion"]
                        }
                    }
                },
                "required": ["total_points", "passing_threshold"]
            },
            "assessment_methods": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "method_id": {"type": "string"},
                        "name": {"type": "string"},
                        "description": {"type": "string"},
                        "tools": {"type": "array", "items": {"type": "string"}},
                        "data_collection": {
                            "type": "object",
                            "properties": {
                                "format": {"type": "string"},
                                "frequency": {"type": "string"},
                                "storage": {"type": "string"}
                            },
                            "required": ["format"]
                        }
                    },
                    "required": ["method_id", "name", "description"]
                }
            },
            "feedback_guidelines": {
                "type": "object",
                "properties": {
                    "timing": {"type": "string"},
                    "format": {"type": "string"},
                    "components": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "component": {"type": "string"},
                                "description": {"type": "string"},
                                "examples": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["component", "description"]
                        }
                    }
                },
                "required": ["timing", "format"]
            },
            "accommodations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string"},
                        "description": {"type": "string"},
                        "eligibility_criteria": {"type": "array", "items": {"type": "string"}},
                        "implementation_guidelines": {"type": "string"}
                    },
                    "required": ["type", "description"]
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
        "required": ["timestamp", "criteria_id", "title", "description", "subject_area", "educational_level", "assessment_type", "evaluation_criteria", "scoring_rubric", "assessment_methods"]
    }
) 