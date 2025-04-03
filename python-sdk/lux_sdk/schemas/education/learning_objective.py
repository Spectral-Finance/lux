"""
Learning Objective Schema

This schema represents learning objectives and educational goals, including
competencies, assessment criteria, and learning outcomes.
"""

from lux_sdk.signals import SignalSchema

LearningObjectiveSchema = SignalSchema(
    name="learning_objective",
    version="1.0",
    description="Schema for defining and tracking learning objectives and educational goals",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "objective_id": {
                "type": "string",
                "description": "Unique identifier for this learning objective"
            },
            "title": {
                "type": "string",
                "description": "Title of the learning objective"
            },
            "description": {
                "type": "string",
                "description": "Detailed description of the objective"
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
                            "type": "string",
                            "description": "Related subject areas"
                        }
                    },
                    "level": {
                        "type": "string",
                        "description": "Educational level"
                    }
                },
                "required": ["primary", "level"]
            },
            "competencies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "competency_id": {
                            "type": "string",
                            "description": "Identifier for this competency"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the competency"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the competency"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["knowledge", "skill", "attitude", "behavior"],
                            "description": "Type of competency"
                        },
                        "level": {
                            "type": "string",
                            "enum": ["foundational", "intermediate", "advanced", "expert"],
                            "description": "Competency level"
                        }
                    },
                    "required": ["competency_id", "name", "type"]
                }
            },
            "learning_outcomes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "outcome_id": {
                            "type": "string",
                            "description": "Identifier for this outcome"
                        },
                        "statement": {
                            "type": "string",
                            "description": "Outcome statement"
                        },
                        "bloom_level": {
                            "type": "string",
                            "enum": ["remember", "understand", "apply", "analyze", "evaluate", "create"],
                            "description": "Bloom's taxonomy level"
                        },
                        "indicators": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Observable indicators of achievement"
                            }
                        }
                    },
                    "required": ["outcome_id", "statement", "bloom_level"]
                }
            },
            "prerequisites": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "objective_id": {
                            "type": "string",
                            "description": "ID of prerequisite objective"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["required", "recommended"],
                            "description": "Type of prerequisite"
                        },
                        "rationale": {
                            "type": "string",
                            "description": "Why this is a prerequisite"
                        }
                    },
                    "required": ["objective_id", "type"]
                }
            },
            "assessment_criteria": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion_id": {
                            "type": "string",
                            "description": "Identifier for this criterion"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the criterion"
                        },
                        "performance_levels": {
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
                                    "score_range": {
                                        "type": "object",
                                        "properties": {
                                            "min": {
                                                "type": "number",
                                                "description": "Minimum score"
                                            },
                                            "max": {
                                                "type": "number",
                                                "description": "Maximum score"
                                            }
                                        }
                                    }
                                },
                                "required": ["level", "description"]
                            }
                        },
                        "weight": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Weight in overall assessment"
                        }
                    },
                    "required": ["criterion_id", "description", "performance_levels"]
                }
            },
            "instructional_strategies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "strategy_id": {
                            "type": "string",
                            "description": "Identifier for this strategy"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the strategy"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the strategy"
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
                                        "type": "string",
                                        "description": "Expected duration"
                                    },
                                    "resources": {
                                        "type": "array",
                                        "items": {
                                            "type": "string",
                                            "description": "Required resources"
                                        }
                                    }
                                },
                                "required": ["name", "duration"]
                            }
                        }
                    },
                    "required": ["strategy_id", "name", "description"]
                }
            },
            "alignment": {
                "type": "object",
                "properties": {
                    "standards": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "framework": {
                                    "type": "string",
                                    "description": "Standards framework"
                                },
                                "identifier": {
                                    "type": "string",
                                    "description": "Standard identifier"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Standard description"
                                }
                            },
                            "required": ["framework", "identifier"]
                        }
                    },
                    "curriculum": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "program": {
                                    "type": "string",
                                    "description": "Program name"
                                },
                                "course": {
                                    "type": "string",
                                    "description": "Course name"
                                },
                                "unit": {
                                    "type": "string",
                                    "description": "Unit name"
                                }
                            },
                            "required": ["program"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {
                        "type": "string",
                        "description": "ID of objective creator"
                    },
                    "creation_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the objective was created"
                    },
                    "last_modified": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When last modified"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the objective"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "archived"],
                        "description": "Current status"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "objective_id", "title", "description", "subject_area", "competencies", "learning_outcomes"]
    }
) 