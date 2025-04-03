"""
TaskPlan Schema

This schema defines the structure for representing task execution plans,
including goals, steps, dependencies, and resource requirements.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "plan_id": "task_20240320_153000",
    "goal": {
        "description": "Deploy new ML model to production",
        "success_criteria": ["Model accuracy > 95%", "Latency < 100ms"],
        "priority": 0.9
    },
    "steps": [
        {
            "id": "step_1",
            "name": "Model validation",
            "description": "Run final validation tests",
            "status": "in_progress",
            "dependencies": [],
            "estimated_duration": 1800,
            "progress": 0.6
        },
        {
            "id": "step_2",
            "name": "Infrastructure setup",
            "description": "Prepare deployment environment",
            "status": "pending",
            "dependencies": ["step_1"],
            "estimated_duration": 3600,
            "progress": 0.0
        }
    ],
    "resources": {
        "compute": {
            "type": "gpu",
            "quantity": 2,
            "status": "allocated"
        },
        "memory": {
            "type": "ram",
            "quantity": 16,
            "unit": "GB"
        }
    },
    "metadata": {
        "owner": "team_ml",
        "priority": "high",
        "deadline": "2024-03-21T00:00:00Z"
    }
}
```
"""

from lux_sdk.signals import SignalSchema

TaskPlanSchema = SignalSchema(
    name="task_plan",
    version="1.0",
    description="Schema for representing task execution plans",
    schema={
        "type": "object",
        "required": ["timestamp", "plan_id", "goal", "steps", "metadata"],
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "Plan creation timestamp"
            },
            "plan_id": {
                "type": "string",
                "description": "Unique plan identifier"
            },
            "goal": {
                "type": "object",
                "required": ["description", "success_criteria"],
                "properties": {
                    "description": {
                        "type": "string",
                        "description": "Goal description"
                    },
                    "success_criteria": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Success criteria"
                    },
                    "priority": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Goal priority"
                    }
                }
            },
            "steps": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["id", "name", "description", "status", "dependencies"],
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": "Step identifier"
                        },
                        "name": {
                            "type": "string",
                            "description": "Step name"
                        },
                        "description": {
                            "type": "string",
                            "description": "Step description"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["pending", "in_progress", "completed", "failed"],
                            "description": "Step status"
                        },
                        "dependencies": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Step dependencies"
                        },
                        "estimated_duration": {
                            "type": "number",
                            "minimum": 0,
                            "description": "Estimated duration in seconds"
                        },
                        "progress": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Step progress"
                        }
                    }
                }
            },
            "resources": {
                "type": "object",
                "properties": {
                    "compute": {
                        "type": "object",
                        "properties": {
                            "type": {
                                "type": "string",
                                "description": "Compute resource type"
                            },
                            "quantity": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Resource quantity"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["required", "requested", "allocated"],
                                "description": "Resource status"
                            }
                        }
                    },
                    "memory": {
                        "type": "object",
                        "properties": {
                            "type": {
                                "type": "string",
                                "description": "Memory type"
                            },
                            "quantity": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Memory quantity"
                            },
                            "unit": {
                                "type": "string",
                                "description": "Memory unit"
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "required": ["owner", "priority"],
                "properties": {
                    "owner": {
                        "type": "string",
                        "description": "Task owner"
                    },
                    "priority": {
                        "type": "string",
                        "enum": ["low", "medium", "high", "critical"],
                        "description": "Task priority"
                    },
                    "deadline": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Task deadline"
                    }
                }
            }
        },
        "additionalProperties": False
    }
) 