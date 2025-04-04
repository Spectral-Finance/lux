"""
Dependency Chain Schema

This schema represents task dependency chains and relationships,
including sequential, parallel, and conditional dependencies.
"""

from lux_sdk.signals import SignalSchema

DependencyChainSchema = SignalSchema(
    name="dependency_chain",
    version="1.0",
    description="Schema for task dependency chains and relationships",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "chain_id": {
                "type": "string",
                "description": "Unique identifier for this dependency chain"
            },
            "name": {
                "type": "string",
                "description": "Name of the dependency chain"
            },
            "description": {
                "type": "string",
                "description": "Description of the dependency chain"
            },
            "tasks": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "task_id": {
                            "type": "string",
                            "description": "Unique identifier for the task"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the task"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["milestone", "deliverable", "activity", "checkpoint", "other"],
                            "description": "Type of task"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["not_started", "in_progress", "completed", "blocked", "cancelled"],
                            "description": "Current status of the task"
                        },
                        "timeline": {
                            "type": "object",
                            "properties": {
                                "planned_start": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Planned start time"
                                },
                                "planned_end": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Planned end time"
                                },
                                "actual_start": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Actual start time"
                                },
                                "actual_end": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Actual end time"
                                }
                            }
                        }
                    },
                    "required": ["task_id", "name", "type", "status"]
                }
            },
            "dependencies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "dependency_id": {
                            "type": "string",
                            "description": "Unique identifier for the dependency"
                        },
                        "predecessor_id": {
                            "type": "string",
                            "description": "ID of the predecessor task"
                        },
                        "successor_id": {
                            "type": "string",
                            "description": "ID of the successor task"
                        },
                        "type": {
                            "type": "string",
                            "enum": [
                                "finish_to_start",
                                "start_to_start",
                                "finish_to_finish",
                                "start_to_finish",
                                "conditional",
                                "resource_based"
                            ],
                            "description": "Type of dependency"
                        },
                        "lag": {
                            "type": "object",
                            "properties": {
                                "duration": {
                                    "type": "number",
                                    "description": "Duration of lag"
                                },
                                "unit": {
                                    "type": "string",
                                    "enum": ["minutes", "hours", "days", "weeks", "months"],
                                    "description": "Unit of lag duration"
                                }
                            }
                        },
                        "conditions": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "description": "Type of condition"
                                    },
                                    "expression": {
                                        "type": "string",
                                        "description": "Condition expression"
                                    },
                                    "description": {
                                        "type": "string",
                                        "description": "Description of the condition"
                                    }
                                },
                                "required": ["type", "expression"]
                            }
                        }
                    },
                    "required": ["dependency_id", "predecessor_id", "successor_id", "type"]
                }
            },
            "critical_path": {
                "type": "array",
                "items": {
                    "type": "string",
                    "description": "Task IDs in the critical path"
                },
                "description": "Sequence of tasks forming the critical path"
            },
            "constraints": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "constraint_id": {
                            "type": "string",
                            "description": "Unique identifier for the constraint"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["must_start_on", "must_finish_on", "start_no_earlier_than", "finish_no_later_than"],
                            "description": "Type of constraint"
                        },
                        "task_id": {
                            "type": "string",
                            "description": "ID of the constrained task"
                        },
                        "date": {
                            "type": "string",
                            "format": "date-time",
                            "description": "Constraint date"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the constraint"
                        }
                    },
                    "required": ["constraint_id", "type", "task_id", "date"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the dependency chain"
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
                        "description": "Version of the dependency chain"
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
            "chain_id",
            "name",
            "tasks",
            "dependencies"
        ]
    }
) 