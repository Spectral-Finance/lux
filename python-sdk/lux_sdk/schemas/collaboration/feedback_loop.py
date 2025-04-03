"""
Feedback Loop Schema

This schema represents collaborative feedback loops and improvement processes,
including feedback collection, analysis, and implementation tracking.
"""

from lux_sdk.signals import SignalSchema

FeedbackLoopSchema = SignalSchema(
    name="feedback_loop",
    version="1.0",
    description="Schema for collaborative feedback loops and improvement processes",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "feedback_id": {
                "type": "string",
                "description": "Unique identifier for this feedback loop"
            },
            "context": {
                "type": "object",
                "properties": {
                    "source_type": {
                        "type": "string",
                        "enum": ["project", "process", "product", "service", "team", "other"],
                        "description": "Type of feedback source"
                    },
                    "source_id": {
                        "type": "string",
                        "description": "Identifier of feedback source"
                    },
                    "scope": {
                        "type": "string",
                        "enum": ["individual", "team", "department", "organization", "system"],
                        "description": "Scope of feedback"
                    },
                    "participants": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "participant_id": {
                                    "type": "string",
                                    "description": "Participant identifier"
                                },
                                "role": {
                                    "type": "string",
                                    "description": "Role in feedback process"
                                }
                            },
                            "required": ["participant_id", "role"]
                        }
                    }
                },
                "required": ["source_type", "source_id", "scope"]
            },
            "feedback_collection": {
                "type": "object",
                "properties": {
                    "method": {
                        "type": "string",
                        "enum": ["survey", "interview", "observation", "metrics", "discussion", "other"],
                        "description": "Method of collecting feedback"
                    },
                    "frequency": {
                        "type": "string",
                        "description": "Frequency of collection"
                    },
                    "data_points": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "When data was collected"
                                },
                                "collector_id": {
                                    "type": "string",
                                    "description": "Who collected the data"
                                },
                                "content": {
                                    "type": "object",
                                    "properties": {
                                        "category": {
                                            "type": "string",
                                            "description": "Feedback category"
                                        },
                                        "description": {
                                            "type": "string",
                                            "description": "Detailed feedback"
                                        },
                                        "rating": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 10,
                                            "description": "Numerical rating if applicable"
                                        }
                                    },
                                    "required": ["category", "description"]
                                }
                            },
                            "required": ["timestamp", "content"]
                        }
                    }
                },
                "required": ["method", "data_points"]
            },
            "analysis": {
                "type": "object",
                "properties": {
                    "summary": {
                        "type": "object",
                        "properties": {
                            "key_findings": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "Main findings from analysis"
                                }
                            },
                            "trends": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "trend_type": {
                                            "type": "string",
                                            "description": "Type of trend"
                                        },
                                        "description": {
                                            "type": "string",
                                            "description": "Trend description"
                                        },
                                        "significance": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 1,
                                            "description": "Significance level"
                                        }
                                    },
                                    "required": ["trend_type", "description"]
                                }
                            }
                        }
                    },
                    "metrics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Metric name"
                                },
                                "value": {
                                    "type": "number",
                                    "description": "Metric value"
                                },
                                "target": {
                                    "type": "number",
                                    "description": "Target value"
                                },
                                "trend": {
                                    "type": "string",
                                    "enum": ["improving", "stable", "declining"],
                                    "description": "Trend direction"
                                }
                            },
                            "required": ["name", "value"]
                        }
                    }
                }
            },
            "action_items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "item_id": {
                            "type": "string",
                            "description": "Action item identifier"
                        },
                        "description": {
                            "type": "string",
                            "description": "What needs to be done"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"],
                            "description": "Priority level"
                        },
                        "assignee": {
                            "type": "string",
                            "description": "Person responsible"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["pending", "in_progress", "completed", "blocked"],
                            "description": "Current status"
                        },
                        "timeline": {
                            "type": "object",
                            "properties": {
                                "start_date": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "When to start"
                                },
                                "due_date": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "When to complete"
                                }
                            }
                        }
                    },
                    "required": ["item_id", "description", "priority", "status"]
                }
            },
            "outcomes": {
                "type": "object",
                "properties": {
                    "improvements": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "area": {
                                    "type": "string",
                                    "description": "Area of improvement"
                                },
                                "impact": {
                                    "type": "string",
                                    "description": "Impact of improvement"
                                },
                                "measurement": {
                                    "type": "object",
                                    "properties": {
                                        "metric": {
                                            "type": "string",
                                            "description": "Measurement metric"
                                        },
                                        "before": {
                                            "type": "number",
                                            "description": "Value before improvement"
                                        },
                                        "after": {
                                            "type": "number",
                                            "description": "Value after improvement"
                                        }
                                    }
                                }
                            },
                            "required": ["area", "impact"]
                        }
                    },
                    "lessons_learned": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Lessons learned from the process"
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of feedback loop"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["active", "completed", "archived"],
                        "description": "Current status"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Relevant tags"
                        }
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "feedback_id",
            "context",
            "feedback_collection"
        ]
    }
) 