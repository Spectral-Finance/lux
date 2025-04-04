"""
Learning Progress Schema

This schema represents learning progress tracking, including achievements,
milestones, and performance metrics in educational contexts.
"""

from lux_sdk.signals import SignalSchema

LearningProgressSchema = SignalSchema(
    name="learning_progress",
    version="1.0",
    description="Schema for tracking learning progress and achievements in educational contexts",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "progress_id": {
                "type": "string",
                "description": "Unique identifier for this progress record"
            },
            "learner_id": {
                "type": "string",
                "description": "Identifier of the learner"
            },
            "objective_id": {
                "type": "string",
                "description": "ID of the associated learning objective"
            },
            "progress_metrics": {
                "type": "object",
                "properties": {
                    "completion_percentage": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100,
                        "description": "Overall completion percentage"
                    },
                    "mastery_level": {
                        "type": "string",
                        "enum": ["novice", "developing", "proficient", "expert"],
                        "description": "Current mastery level"
                    },
                    "time_spent": {
                        "type": "object",
                        "properties": {
                            "total_hours": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Total hours spent on learning"
                            },
                            "active_learning": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Hours of active engagement"
                            },
                            "practice": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Hours spent practicing"
                            }
                        },
                        "required": ["total_hours"]
                    }
                },
                "required": ["completion_percentage", "mastery_level"]
            },
            "achievements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "achievement_id": {
                            "type": "string",
                            "description": "Identifier for this achievement"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the achievement"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the achievement"
                        },
                        "date_earned": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When the achievement was earned"
                        },
                        "criteria_met": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Criteria satisfied for this achievement"
                            }
                        }
                    },
                    "required": ["achievement_id", "name", "date_earned"]
                }
            },
            "competency_progress": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "competency_id": {
                            "type": "string",
                            "description": "ID of the competency"
                        },
                        "level": {
                            "type": "string",
                            "enum": ["not_started", "in_progress", "mastered"],
                            "description": "Current progress level"
                        },
                        "evidence": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "description": "Type of evidence"
                                    },
                                    "description": {
                                        "type": "string",
                                        "description": "Description of the evidence"
                                    },
                                    "date": {
                                        "type": "string",
                                        "format": "date-time",
                                        "description": "When evidence was recorded"
                                    }
                                },
                                "required": ["type", "description", "date"]
                            }
                        }
                    },
                    "required": ["competency_id", "level"]
                }
            },
            "assessment_results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "assessment_id": {
                            "type": "string",
                            "description": "ID of the assessment"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["quiz", "exam", "project", "presentation", "other"],
                            "description": "Type of assessment"
                        },
                        "date": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When assessment was completed"
                        },
                        "score": {
                            "type": "object",
                            "properties": {
                                "value": {
                                    "type": "number",
                                    "description": "Numerical score"
                                },
                                "max_possible": {
                                    "type": "number",
                                    "description": "Maximum possible score"
                                },
                                "percentage": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 100,
                                    "description": "Score as percentage"
                                }
                            },
                            "required": ["value", "max_possible", "percentage"]
                        },
                        "feedback": {
                            "type": "string",
                            "description": "Assessment feedback"
                        }
                    },
                    "required": ["assessment_id", "type", "date", "score"]
                }
            },
            "learning_path": {
                "type": "object",
                "properties": {
                    "current_stage": {
                        "type": "string",
                        "description": "Current stage in learning path"
                    },
                    "completed_stages": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Completed learning stages"
                        }
                    },
                    "next_steps": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "step_id": {
                                    "type": "string",
                                    "description": "ID of next learning step"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of next step"
                                },
                                "estimated_duration": {
                                    "type": "string",
                                    "description": "Estimated time to complete"
                                }
                            },
                            "required": ["step_id", "description"]
                        }
                    }
                },
                "required": ["current_stage", "completed_stages"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When progress was last updated"
                    },
                    "tracking_method": {
                        "type": "string",
                        "description": "Method used to track progress"
                    },
                    "data_source": {
                        "type": "string",
                        "description": "Source of progress data"
                    },
                    "notes": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Additional notes about progress"
                        }
                    }
                },
                "required": ["last_updated"]
            }
        },
        "required": [
            "timestamp",
            "progress_id",
            "learner_id",
            "objective_id",
            "progress_metrics",
            "competency_progress"
        ]
    }
) 