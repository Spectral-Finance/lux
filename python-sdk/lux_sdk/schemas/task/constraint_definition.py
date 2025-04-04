"""
Constraint Definition Schema

This schema represents task constraints and limitations,
including temporal, resource, and dependency constraints.
"""

from lux_sdk.signals import SignalSchema

ConstraintDefinitionSchema = SignalSchema(
    name="constraint_definition",
    version="1.0",
    description="Schema for task constraints and limitations",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "constraint_id": {
                "type": "string",
                "description": "Unique identifier for this constraint"
            },
            "task_id": {
                "type": "string",
                "description": "ID of the task this constraint applies to"
            },
            "name": {
                "type": "string",
                "description": "Name of the constraint"
            },
            "description": {
                "type": "string",
                "description": "Detailed description of the constraint"
            },
            "type": {
                "type": "string",
                "enum": [
                    "temporal",
                    "resource",
                    "dependency",
                    "quality",
                    "regulatory",
                    "technical",
                    "business",
                    "environmental"
                ],
                "description": "Type of constraint"
            },
            "temporal_constraints": {
                "type": "object",
                "properties": {
                    "earliest_start": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Earliest allowed start time"
                    },
                    "latest_start": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Latest allowed start time"
                    },
                    "earliest_finish": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Earliest allowed finish time"
                    },
                    "deadline": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Hard deadline"
                    },
                    "duration_limits": {
                        "type": "object",
                        "properties": {
                            "minimum": {
                                "type": "string",
                                "description": "Minimum duration"
                            },
                            "maximum": {
                                "type": "string",
                                "description": "Maximum duration"
                            },
                            "preferred": {
                                "type": "string",
                                "description": "Preferred duration"
                            }
                        }
                    },
                    "time_windows": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "start": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Window start time"
                                },
                                "end": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Window end time"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["allowed", "blocked"],
                                    "description": "Type of time window"
                                }
                            },
                            "required": ["start", "end", "type"]
                        }
                    }
                }
            },
            "resource_constraints": {
                "type": "object",
                "properties": {
                    "required_resources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "resource_id": {
                                    "type": "string",
                                    "description": "Resource identifier"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Type of resource"
                                },
                                "quantity": {
                                    "type": "number",
                                    "description": "Required quantity"
                                },
                                "units": {
                                    "type": "string",
                                    "description": "Units of measurement"
                                },
                                "substitutes": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Acceptable substitute resources"
                                }
                            },
                            "required": ["resource_id", "quantity"]
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
                                "available_quantity": {
                                    "type": "number",
                                    "description": "Available quantity"
                                },
                                "time_period": {
                                    "type": "object",
                                    "properties": {
                                        "start": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Period start"
                                        },
                                        "end": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Period end"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "dependency_constraints": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "dependency_type": {
                            "type": "string",
                            "enum": ["finish_to_start", "start_to_start", "finish_to_finish", "start_to_finish"],
                            "description": "Type of dependency"
                        },
                        "predecessor_id": {
                            "type": "string",
                            "description": "ID of predecessor task"
                        },
                        "lag": {
                            "type": "string",
                            "description": "Time lag between tasks"
                        },
                        "flexibility": {
                            "type": "string",
                            "enum": ["mandatory", "discretionary", "external"],
                            "description": "Flexibility of the dependency"
                        }
                    },
                    "required": ["dependency_type", "predecessor_id"]
                }
            },
            "quality_constraints": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "metric": {
                            "type": "string",
                            "description": "Quality metric"
                        },
                        "threshold": {
                            "type": "number",
                            "description": "Required threshold"
                        },
                        "operator": {
                            "type": "string",
                            "enum": ["greater_than", "less_than", "equal_to", "not_equal_to"],
                            "description": "Comparison operator"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["must_have", "should_have", "nice_to_have"],
                            "description": "Priority of the constraint"
                        }
                    },
                    "required": ["metric", "threshold", "operator"]
                }
            },
            "validation_rules": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "rule_id": {
                            "type": "string",
                            "description": "Unique identifier for the rule"
                        },
                        "description": {
                            "type": "string",
                            "description": "Rule description"
                        },
                        "validation_method": {
                            "type": "string",
                            "description": "Method to validate the constraint"
                        },
                        "severity": {
                            "type": "string",
                            "enum": ["error", "warning", "info"],
                            "description": "Severity of rule violation"
                        }
                    },
                    "required": ["rule_id", "validation_method"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the constraint"
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
                        "description": "Version of the constraint"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["active", "inactive", "draft", "archived"],
                        "description": "Current status"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "constraint_id",
            "task_id",
            "name",
            "type"
        ]
    }
) 