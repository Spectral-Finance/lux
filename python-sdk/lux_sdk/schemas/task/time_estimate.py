"""
Time Estimate Schema

This schema represents time estimates for tasks and activities,
including duration predictions, scheduling constraints, and historical data.
"""

from lux_sdk.signals import SignalSchema

TimeEstimateSchema = SignalSchema(
    name="time_estimate",
    version="1.0",
    description="Schema for task time estimation and scheduling",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "estimate_id": {
                "type": "string",
                "description": "Unique identifier for this time estimate"
            },
            "task_id": {
                "type": "string",
                "description": "ID of the task being estimated"
            },
            "duration_estimate": {
                "type": "object",
                "properties": {
                    "expected_duration": {
                        "type": "object",
                        "properties": {
                            "value": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Expected duration value"
                            },
                            "unit": {
                                "type": "string",
                                "enum": ["minutes", "hours", "days", "weeks", "months"],
                                "description": "Time unit"
                            }
                        },
                        "required": ["value", "unit"]
                    },
                    "confidence_level": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in the estimate"
                    },
                    "range": {
                        "type": "object",
                        "properties": {
                            "minimum": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Minimum duration"
                            },
                            "maximum": {
                                "type": "number",
                                "description": "Maximum duration"
                            },
                            "unit": {
                                "type": "string",
                                "enum": ["minutes", "hours", "days", "weeks", "months"],
                                "description": "Time unit"
                            }
                        },
                        "required": ["minimum", "maximum", "unit"]
                    }
                },
                "required": ["expected_duration"]
            },
            "scheduling_constraints": {
                "type": "object",
                "properties": {
                    "earliest_start": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Earliest possible start time"
                    },
                    "deadline": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Required completion time"
                    },
                    "dependencies": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "task_id": {
                                    "type": "string",
                                    "description": "Dependent task ID"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["finish_to_start", "start_to_start", "finish_to_finish", "start_to_finish"],
                                    "description": "Type of dependency"
                                },
                                "lag": {
                                    "type": "object",
                                    "properties": {
                                        "value": {
                                            "type": "number",
                                            "description": "Lag duration"
                                        },
                                        "unit": {
                                            "type": "string",
                                            "enum": ["minutes", "hours", "days"],
                                            "description": "Time unit"
                                        }
                                    }
                                }
                            },
                            "required": ["task_id", "type"]
                        }
                    },
                    "resource_availability": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "resource_id": {
                                    "type": "string",
                                    "description": "Resource identifier"
                                },
                                "availability_windows": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "start": {
                                                "type": "string",
                                                "format": "date-time",
                                                "description": "Start of availability"
                                            },
                                            "end": {
                                                "type": "string",
                                                "format": "date-time",
                                                "description": "End of availability"
                                            },
                                            "capacity": {
                                                "type": "number",
                                                "minimum": 0,
                                                "maximum": 1,
                                                "description": "Available capacity"
                                            }
                                        },
                                        "required": ["start", "end"]
                                    }
                                }
                            },
                            "required": ["resource_id", "availability_windows"]
                        }
                    }
                }
            },
            "historical_data": {
                "type": "object",
                "properties": {
                    "similar_tasks": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "task_id": {
                                    "type": "string",
                                    "description": "Similar task ID"
                                },
                                "similarity_score": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Similarity to current task"
                                },
                                "actual_duration": {
                                    "type": "object",
                                    "properties": {
                                        "value": {
                                            "type": "number",
                                            "minimum": 0,
                                            "description": "Actual duration"
                                        },
                                        "unit": {
                                            "type": "string",
                                            "enum": ["minutes", "hours", "days", "weeks", "months"],
                                            "description": "Time unit"
                                        }
                                    },
                                    "required": ["value", "unit"]
                                }
                            },
                            "required": ["task_id", "actual_duration"]
                        }
                    },
                    "performance_factors": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "factor": {
                                    "type": "string",
                                    "description": "Performance factor"
                                },
                                "impact": {
                                    "type": "number",
                                    "minimum": -1,
                                    "maximum": 1,
                                    "description": "Impact on duration"
                                }
                            },
                            "required": ["factor", "impact"]
                        }
                    }
                }
            },
            "revision_history": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "revision_timestamp": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When estimate was revised"
                        },
                        "previous_estimate": {
                            "type": "object",
                            "properties": {
                                "value": {
                                    "type": "number",
                                    "minimum": 0,
                                    "description": "Previous duration estimate"
                                },
                                "unit": {
                                    "type": "string",
                                    "enum": ["minutes", "hours", "days", "weeks", "months"],
                                    "description": "Time unit"
                                }
                            },
                            "required": ["value", "unit"]
                        },
                        "reason": {
                            "type": "string",
                            "description": "Reason for revision"
                        }
                    },
                    "required": ["revision_timestamp", "previous_estimate"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "estimator": {
                        "type": "string",
                        "description": "ID of person/system making estimate"
                    },
                    "estimation_method": {
                        "type": "string",
                        "description": "Method used for estimation"
                    },
                    "assumptions": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Assumptions made"
                        }
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "estimate_id",
            "task_id",
            "duration_estimate"
        ]
    }
) 