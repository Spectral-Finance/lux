"""
Learning Resource Schema

This schema represents learning resources and educational materials,
including content, metadata, and pedagogical information.
"""

from lux_sdk.signals import SignalSchema

LearningResourceSchema = SignalSchema(
    name="learning_resource",
    version="1.0",
    description="Schema for learning resources and educational materials",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "resource_id": {
                "type": "string",
                "description": "Unique identifier for this learning resource"
            },
            "title": {
                "type": "string",
                "description": "Title of the resource"
            },
            "description": {
                "type": "string",
                "description": "Detailed description"
            },
            "type": {
                "type": "string",
                "enum": [
                    "lesson",
                    "assessment",
                    "activity",
                    "video",
                    "interactive",
                    "reading",
                    "simulation",
                    "game",
                    "worksheet",
                    "presentation"
                ],
                "description": "Type of learning resource"
            },
            "subject_area": {
                "type": "object",
                "properties": {
                    "primary": {
                        "type": "string",
                        "description": "Primary subject area"
                    },
                    "secondary": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Related subject areas"
                    },
                    "keywords": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Subject keywords"
                    }
                },
                "required": ["primary"]
            },
            "educational_context": {
                "type": "object",
                "properties": {
                    "education_level": {
                        "type": "string",
                        "enum": [
                            "early_childhood",
                            "primary",
                            "secondary",
                            "higher_education",
                            "professional",
                            "adult_learning"
                        ],
                        "description": "Target education level"
                    },
                    "age_range": {
                        "type": "object",
                        "properties": {
                            "min": {
                                "type": "number",
                                "description": "Minimum age"
                            },
                            "max": {
                                "type": "number",
                                "description": "Maximum age"
                            }
                        }
                    },
                    "difficulty_level": {
                        "type": "string",
                        "enum": ["beginner", "intermediate", "advanced", "expert"],
                        "description": "Difficulty level"
                    },
                    "prerequisites": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Required prerequisites"
                    }
                },
                "required": ["education_level"]
            },
            "learning_objectives": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "objective_id": {
                            "type": "string",
                            "description": "Objective identifier"
                        },
                        "description": {
                            "type": "string",
                            "description": "Objective description"
                        },
                        "bloom_level": {
                            "type": "string",
                            "enum": [
                                "remember",
                                "understand",
                                "apply",
                                "analyze",
                                "evaluate",
                                "create"
                            ],
                            "description": "Bloom's taxonomy level"
                        },
                        "assessment_criteria": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Success criteria"
                        }
                    },
                    "required": ["objective_id", "description"]
                }
            },
            "content": {
                "type": "object",
                "properties": {
                    "format": {
                        "type": "string",
                        "description": "Content format"
                    },
                    "language": {
                        "type": "string",
                        "description": "Content language"
                    },
                    "duration": {
                        "type": "number",
                        "description": "Duration in minutes"
                    },
                    "materials": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Material type"
                                },
                                "url": {
                                    "type": "string",
                                    "description": "Resource URL"
                                },
                                "format": {
                                    "type": "string",
                                    "description": "File format"
                                },
                                "size": {
                                    "type": "number",
                                    "description": "File size in bytes"
                                }
                            }
                        }
                    },
                    "accessibility": {
                        "type": "object",
                        "properties": {
                            "features": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Accessibility features"
                            },
                            "conformance_level": {
                                "type": "string",
                                "description": "WCAG conformance level"
                            }
                        }
                    }
                }
            },
            "instructional_strategies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "strategy": {
                            "type": "string",
                            "description": "Teaching strategy"
                        },
                        "description": {
                            "type": "string",
                            "description": "Strategy description"
                        },
                        "activities": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {
                                        "type": "string",
                                        "description": "Activity name"
                                    },
                                    "duration": {
                                        "type": "number",
                                        "description": "Duration in minutes"
                                    },
                                    "instructions": {
                                        "type": "string",
                                        "description": "Activity instructions"
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "assessment": {
                "type": "object",
                "properties": {
                    "methods": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Assessment methods"
                    },
                    "rubric": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "criterion": {
                                    "type": "string",
                                    "description": "Assessment criterion"
                                },
                                "levels": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "level": {
                                                "type": "string",
                                                "description": "Performance level"
                                            },
                                            "description": {
                                                "type": "string",
                                                "description": "Level description"
                                            },
                                            "points": {
                                                "type": "number",
                                                "description": "Points awarded"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of resource"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version number"
                    },
                    "license": {
                        "type": "string",
                        "description": "License information"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Resource tags"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "resource_id",
            "title",
            "type",
            "subject_area",
            "educational_context",
            "learning_objectives"
        ]
    }
) 