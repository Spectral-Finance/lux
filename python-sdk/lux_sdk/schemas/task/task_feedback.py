"""
Task Feedback Schema

This schema represents feedback and performance assessment for tasks,
including evaluation metrics, suggestions for improvement, and progress tracking.
"""

from lux_sdk.signals import SignalSchema

TaskFeedbackSchema = SignalSchema(
    name="task_feedback",
    version="1.0",
    description="Schema for task feedback and performance assessment",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "feedback_id": {
                "type": "string",
                "description": "Unique identifier for this feedback"
            },
            "task_reference": {
                "type": "object",
                "properties": {
                    "task_id": {
                        "type": "string",
                        "description": "ID of the task being evaluated"
                    },
                    "task_name": {
                        "type": "string",
                        "description": "Name of the task"
                    },
                    "task_type": {
                        "type": "string",
                        "description": "Type or category of the task"
                    },
                    "assignee": {
                        "type": "string",
                        "description": "Person or system assigned to the task"
                    }
                },
                "required": ["task_id", "task_name"]
            },
            "performance_metrics": {
                "type": "object",
                "properties": {
                    "completion_rate": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100,
                        "description": "Percentage of task completion"
                    },
                    "quality_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100,
                        "description": "Quality assessment score"
                    },
                    "time_efficiency": {
                        "type": "object",
                        "properties": {
                            "actual_duration": {
                                "type": "number",
                                "description": "Actual time taken in minutes"
                            },
                            "expected_duration": {
                                "type": "number",
                                "description": "Expected time in minutes"
                            },
                            "efficiency_ratio": {
                                "type": "number",
                                "description": "Ratio of actual to expected duration"
                            }
                        }
                    },
                    "error_rate": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Rate of errors per unit of work"
                    },
                    "custom_metrics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Name of the custom metric"
                                },
                                "value": {
                                    "type": "number",
                                    "description": "Value of the metric"
                                },
                                "unit": {
                                    "type": "string",
                                    "description": "Unit of measurement"
                                }
                            },
                            "required": ["name", "value"]
                        }
                    }
                },
                "required": ["completion_rate", "quality_score"]
            },
            "evaluation": {
                "type": "object",
                "properties": {
                    "strengths": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Identified strengths in task execution"
                        }
                    },
                    "areas_for_improvement": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "area": {
                                    "type": "string",
                                    "description": "Area needing improvement"
                                },
                                "suggestion": {
                                    "type": "string",
                                    "description": "Suggested improvement action"
                                },
                                "priority": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high"],
                                    "description": "Priority of the improvement"
                                }
                            },
                            "required": ["area", "suggestion"]
                        }
                    },
                    "overall_assessment": {
                        "type": "string",
                        "description": "Overall evaluation summary"
                    }
                },
                "required": ["overall_assessment"]
            },
            "feedback_details": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["automated", "manual", "hybrid"],
                        "description": "Type of feedback generation"
                    },
                    "reviewer": {
                        "type": "string",
                        "description": "Person or system providing feedback"
                    },
                    "review_timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the review was conducted"
                    },
                    "feedback_status": {
                        "type": "string",
                        "enum": ["draft", "reviewed", "approved", "delivered"],
                        "description": "Status of the feedback"
                    }
                },
                "required": ["type", "reviewer"]
            },
            "action_items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "action_id": {
                            "type": "string",
                            "description": "Unique identifier for the action item"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the action item"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high"],
                            "description": "Priority level"
                        },
                        "due_date": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When the action should be completed"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["pending", "in_progress", "completed", "cancelled"],
                            "description": "Status of the action item"
                        }
                    },
                    "required": ["action_id", "description", "status"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "feedback_template": {
                        "type": "string",
                        "description": "Template used for feedback"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the feedback schema"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Relevant tags"
                    },
                    "attachments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Name of the attachment"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Type of attachment"
                                },
                                "url": {
                                    "type": "string",
                                    "description": "URL to the attachment"
                                }
                            },
                            "required": ["name", "type"]
                        }
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "feedback_id",
            "task_reference",
            "performance_metrics",
            "evaluation",
            "feedback_details"
        ]
    }
) 