"""
Optimization Goal Schema

This schema represents optimization goals and objectives,
including target metrics, constraints, and evaluation criteria.
"""

from lux_sdk.signals import SignalSchema

OptimizationGoalSchema = SignalSchema(
    name="optimization_goal",
    version="1.0",
    description="Schema for optimization goals and objectives",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "goal_id": {
                "type": "string",
                "description": "Unique identifier for this optimization goal"
            },
            "name": {
                "type": "string",
                "description": "Name of the optimization goal"
            },
            "description": {
                "type": "string",
                "description": "Detailed description of the goal"
            },
            "objective_function": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["minimize", "maximize", "target"],
                        "description": "Type of optimization"
                    },
                    "metric": {
                        "type": "string",
                        "description": "Metric to optimize"
                    },
                    "target_value": {
                        "type": "number",
                        "description": "Target value for the metric"
                    },
                    "weight": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Weight of this objective"
                    },
                    "tolerance": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Acceptable deviation from target"
                    }
                },
                "required": ["type", "metric"]
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
                            "enum": ["equality", "inequality", "range"],
                            "description": "Type of constraint"
                        },
                        "variable": {
                            "type": "string",
                            "description": "Variable being constrained"
                        },
                        "operator": {
                            "type": "string",
                            "enum": ["=", "<", "<=", ">", ">=", "between"],
                            "description": "Constraint operator"
                        },
                        "value": {
                            "type": "number",
                            "description": "Constraint value"
                        },
                        "range": {
                            "type": "object",
                            "properties": {
                                "min": {
                                    "type": "number",
                                    "description": "Minimum value"
                                },
                                "max": {
                                    "type": "number",
                                    "description": "Maximum value"
                                }
                            }
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"],
                            "description": "Priority of the constraint"
                        }
                    },
                    "required": ["constraint_id", "type", "variable"]
                }
            },
            "parameters": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "Parameter name"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["continuous", "discrete", "categorical", "boolean"],
                            "description": "Parameter type"
                        },
                        "range": {
                            "type": "object",
                            "properties": {
                                "min": {
                                    "type": "number",
                                    "description": "Minimum value"
                                },
                                "max": {
                                    "type": "number",
                                    "description": "Maximum value"
                                },
                                "step": {
                                    "type": "number",
                                    "description": "Step size for discrete parameters"
                                }
                            }
                        },
                        "categories": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Possible categories"
                            }
                        },
                        "default_value": {
                            "type": ["number", "string", "boolean"],
                            "description": "Default parameter value"
                        }
                    },
                    "required": ["name", "type"]
                }
            },
            "evaluation_criteria": {
                "type": "object",
                "properties": {
                    "metrics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Metric name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Metric description"
                                },
                                "unit": {
                                    "type": "string",
                                    "description": "Unit of measurement"
                                },
                                "weight": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Weight in evaluation"
                                },
                                "threshold": {
                                    "type": "object",
                                    "properties": {
                                        "min": {
                                            "type": "number",
                                            "description": "Minimum acceptable value"
                                        },
                                        "target": {
                                            "type": "number",
                                            "description": "Target value"
                                        },
                                        "max": {
                                            "type": "number",
                                            "description": "Maximum acceptable value"
                                        }
                                    }
                                }
                            },
                            "required": ["name", "weight"]
                        }
                    },
                    "aggregation_method": {
                        "type": "string",
                        "enum": ["weighted_sum", "weighted_product", "min_max", "custom"],
                        "description": "Method to aggregate metrics"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the goal"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the goal"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "active", "completed", "archived"],
                        "description": "Status of the goal"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "goal_id",
            "name",
            "objective_function",
            "constraints",
            "evaluation_criteria"
        ]
    }
) 