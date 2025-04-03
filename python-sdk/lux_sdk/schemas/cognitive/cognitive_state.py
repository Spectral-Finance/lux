"""
CognitiveState Schema

This schema defines the structure for representing an agent's current cognitive state,
including attention allocation, processing load, active goals, and available cognitive resources.
It helps agents communicate their current cognitive capabilities, limitations, and focus areas.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "attention": {
        "primary_focus": "data_analysis_task_123",
        "focus_duration": 300,  # seconds
        "attention_distribution": {
            "data_analysis": 0.7,
            "system_monitoring": 0.2,
            "user_interaction": 0.1
        },
        "distractions": ["high_system_load", "pending_notifications"]
    },
    "processing_load": {
        "cpu_utilization": 0.85,
        "memory_utilization": 0.72,
        "task_queue_length": 3,
        "context_switches": 12
    },
    "active_goals": [
        {
            "id": "goal_789",
            "description": "Complete statistical analysis of dataset",
            "priority": 0.9,
            "progress": 0.65,
            "estimated_completion": "2024-03-20T16:00:00Z",
            "dependencies": ["data_validation", "model_selection"]
        }
    ],
    "cognitive_resources": {
        "working_memory": {
            "capacity": 0.8,
            "current_load": 0.6,
            "active_items": ["dataset_stats", "analysis_parameters", "interim_results"]
        },
        "processing_capacity": {
            "available": 0.75,
            "reserved": 0.25,
            "throttling": false
        }
    },
    "performance_metrics": {
        "response_time": 150,  # milliseconds
        "accuracy": 0.95,
        "error_rate": 0.02,
        "decision_confidence": 0.88
    },
    "state_assessment": {
        "overall_efficiency": 0.82,
        "bottlenecks": ["memory_intensive_operation"],
        "optimization_suggestions": [
            "Reduce context switching",
            "Offload background tasks"
        ]
    },
    "metadata": {
        "state_id": "cs_20240320_153000",
        "agent_id": "agent_456",
        "measurement_method": "internal_monitoring",
        "reliability_score": 0.94
    }
}
```
"""

from lux_sdk.signals import SignalSchema

CognitiveStateSchema = SignalSchema(
    name="cognitive_state",
    version="1.0",
    description="Schema for representing an agent's current cognitive processing state and resources",
    schema={
        "type": "object",
        "required": [
            "timestamp",
            "attention",
            "processing_load",
            "active_goals",
            "cognitive_resources",
            "performance_metrics",
            "state_assessment",
            "metadata"
        ],
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "ISO 8601 timestamp of when the cognitive state was recorded"
            },
            "attention": {
                "type": "object",
                "required": ["primary_focus", "focus_duration", "attention_distribution"],
                "properties": {
                    "primary_focus": {
                        "type": "string",
                        "description": "Current main focus of attention"
                    },
                    "focus_duration": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Duration of current focus in seconds"
                    },
                    "attention_distribution": {
                        "type": "object",
                        "description": "Distribution of attention across different tasks",
                        "additionalProperties": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1
                        }
                    },
                    "distractions": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "List of current distractions or interruptions"
                    }
                }
            },
            "processing_load": {
                "type": "object",
                "required": ["cpu_utilization", "memory_utilization", "task_queue_length"],
                "properties": {
                    "cpu_utilization": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Current CPU utilization"
                    },
                    "memory_utilization": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Current memory utilization"
                    },
                    "task_queue_length": {
                        "type": "integer",
                        "minimum": 0,
                        "description": "Number of tasks in the processing queue"
                    },
                    "context_switches": {
                        "type": "integer",
                        "minimum": 0,
                        "description": "Number of context switches in current period"
                    }
                }
            },
            "active_goals": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["id", "description", "priority", "progress"],
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": "Unique identifier for the goal"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the goal"
                        },
                        "priority": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Priority level of the goal"
                        },
                        "progress": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Current progress towards goal completion"
                        },
                        "estimated_completion": {
                            "type": "string",
                            "format": "date-time",
                            "description": "Estimated completion time"
                        },
                        "dependencies": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "List of dependencies for this goal"
                        }
                    }
                }
            },
            "cognitive_resources": {
                "type": "object",
                "required": ["working_memory", "processing_capacity"],
                "properties": {
                    "working_memory": {
                        "type": "object",
                        "required": ["capacity", "current_load", "active_items"],
                        "properties": {
                            "capacity": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Total working memory capacity"
                            },
                            "current_load": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Current working memory load"
                            },
                            "active_items": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Currently active items in working memory"
                            }
                        }
                    },
                    "processing_capacity": {
                        "type": "object",
                        "required": ["available", "reserved", "throttling"],
                        "properties": {
                            "available": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Available processing capacity"
                            },
                            "reserved": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Reserved processing capacity"
                            },
                            "throttling": {
                                "type": "boolean",
                                "description": "Whether processing is being throttled"
                            }
                        }
                    }
                }
            },
            "performance_metrics": {
                "type": "object",
                "required": ["response_time", "accuracy", "error_rate", "decision_confidence"],
                "properties": {
                    "response_time": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Average response time in milliseconds"
                    },
                    "accuracy": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Current task accuracy"
                    },
                    "error_rate": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Current error rate"
                    },
                    "decision_confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in current decisions"
                    }
                }
            },
            "state_assessment": {
                "type": "object",
                "required": ["overall_efficiency", "bottlenecks", "optimization_suggestions"],
                "properties": {
                    "overall_efficiency": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Overall cognitive efficiency score"
                    },
                    "bottlenecks": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Identified processing bottlenecks"
                    },
                    "optimization_suggestions": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Suggestions for optimizing cognitive performance"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "required": ["state_id", "agent_id", "measurement_method", "reliability_score"],
                "properties": {
                    "state_id": {
                        "type": "string",
                        "description": "Unique identifier for this cognitive state snapshot"
                    },
                    "agent_id": {
                        "type": "string",
                        "description": "Identifier of the agent reporting the state"
                    },
                    "measurement_method": {
                        "type": "string",
                        "description": "Method used to measure cognitive state"
                    },
                    "reliability_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Reliability score of the measurements"
                    }
                }
            }
        },
        "additionalProperties": False
    }
) 