"""
Progress Update Schema

This schema represents updates on task progress, including completion status,
milestones, blockers, and next steps.
"""

from lux_sdk.signals import SignalSchema

ProgressUpdateSchema = SignalSchema(
    name="progress_update",
    version="1.0",
    description="Schema for tracking and reporting task progress and status updates",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "update_id": {
                "type": "string",
                "description": "Unique identifier for this progress update"
            },
            "task_id": {
                "type": "string",
                "description": "ID of the task being updated"
            },
            "status": {
                "type": "string",
                "enum": ["not_started", "in_progress", "blocked", "completed", "cancelled"],
                "description": "Current status of the task"
            },
            "completion_percentage": {
                "type": "number",
                "minimum": 0,
                "maximum": 100,
                "description": "Percentage of task completion"
            },
            "milestones": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "milestone_id": {
                            "type": "string"
                        },
                        "description": {
                            "type": "string"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["pending", "completed"]
                        },
                        "completion_date": {
                            "type": "string",
                            "format": "date-time"
                        }
                    },
                    "required": ["milestone_id", "description", "status"]
                }
            },
            "blockers": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "blocker_id": {
                            "type": "string"
                        },
                        "description": {
                            "type": "string"
                        },
                        "severity": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"]
                        },
                        "resolution_status": {
                            "type": "string",
                            "enum": ["unresolved", "in_progress", "resolved"]
                        }
                    },
                    "required": ["blocker_id", "description", "severity"]
                }
            },
            "next_steps": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "step_id": {
                            "type": "string"
                        },
                        "description": {
                            "type": "string"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high"]
                        },
                        "estimated_completion": {
                            "type": "string",
                            "format": "date-time"
                        }
                    },
                    "required": ["step_id", "description", "priority"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "reporter": {
                        "type": "string",
                        "description": "ID of the entity reporting the progress"
                    },
                    "update_type": {
                        "type": "string",
                        "enum": ["scheduled", "milestone", "blocker", "completion"],
                        "description": "Type of progress update"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes or context"
                    }
                }
            }
        },
        "required": ["timestamp", "update_id", "task_id", "status", "completion_percentage"]
    }
) 