"""
Fairness Metric Schema

This schema represents the definition and measurement of fairness metrics,
including their calculation, interpretation, and application in assessing
algorithmic and systemic fairness.
"""

from lux_sdk.signals import SignalSchema

FairnessMetricSchema = SignalSchema(
    name="fairness_metric",
    version="1.0",
    description="Schema for defining and measuring fairness metrics",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "metric_id": {
                "type": "string",
                "description": "Unique identifier for this fairness metric"
            },
            "name": {
                "type": "string",
                "description": "Name of the fairness metric"
            },
            "category": {
                "type": "string",
                "enum": [
                    "demographic_parity",
                    "equal_opportunity",
                    "equalized_odds",
                    "predictive_parity",
                    "individual_fairness",
                    "group_fairness",
                    "counterfactual_fairness",
                    "other"
                ],
                "description": "Category of fairness metric"
            },
            "description": {
                "type": "string",
                "description": "Detailed description of the metric"
            },
            "formula": {
                "type": "object",
                "properties": {
                    "mathematical_expression": {
                        "type": "string",
                        "description": "Mathematical formula for the metric"
                    },
                    "variables": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Variable name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Variable description"
                                },
                                "data_type": {
                                    "type": "string",
                                    "description": "Data type of the variable"
                                }
                            },
                            "required": ["name", "description"]
                        }
                    }
                },
                "required": ["mathematical_expression"]
            },
            "measurement": {
                "type": "object",
                "properties": {
                    "method": {
                        "type": "string",
                        "description": "Method for measuring the metric"
                    },
                    "data_requirements": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Required data for measurement"
                    },
                    "computation_steps": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Steps to compute the metric"
                    }
                },
                "required": ["method"]
            },
            "interpretation": {
                "type": "object",
                "properties": {
                    "range": {
                        "type": "object",
                        "properties": {
                            "min": {
                                "type": "number",
                                "description": "Minimum possible value"
                            },
                            "max": {
                                "type": "number",
                                "description": "Maximum possible value"
                            },
                            "optimal": {
                                "type": "number",
                                "description": "Optimal value"
                            }
                        }
                    },
                    "thresholds": {
                        "type": "object",
                        "properties": {
                            "acceptable": {
                                "type": "number",
                                "description": "Minimum acceptable value"
                            },
                            "target": {
                                "type": "number",
                                "description": "Target value"
                            }
                        }
                    },
                    "guidelines": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Guidelines for interpreting results"
                    }
                }
            },
            "limitations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "description": {
                            "type": "string",
                            "description": "Description of limitation"
                        },
                        "impact": {
                            "type": "string",
                            "description": "Impact on metric validity"
                        },
                        "mitigation": {
                            "type": "string",
                            "description": "How to address limitation"
                        }
                    },
                    "required": ["description"]
                }
            },
            "applications": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "context": {
                            "type": "string",
                            "description": "Application context"
                        },
                        "considerations": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Special considerations"
                        }
                    },
                    "required": ["context"]
                }
            },
            "references": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "citation": {
                            "type": "string",
                            "description": "Academic citation"
                        },
                        "url": {
                            "type": "string",
                            "description": "Reference URL"
                        },
                        "relevance": {
                            "type": "string",
                            "description": "Relevance to metric"
                        }
                    },
                    "required": ["citation"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the metric"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "updated_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the metric"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "deprecated"],
                        "description": "Status of the metric"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "metric_id",
            "name",
            "category",
            "description",
            "formula",
            "measurement"
        ]
    }
) 