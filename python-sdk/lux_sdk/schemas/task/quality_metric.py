"""
Quality Metric Schema

This schema represents quality metrics and evaluation criteria for tasks,
including performance indicators, quality checks, and validation results.
"""

from lux_sdk.signals import SignalSchema

QualityMetricSchema = SignalSchema(
    name="quality_metric",
    version="1.0",
    description="Schema for defining and tracking quality metrics for task evaluation",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "metric_id": {
                "type": "string",
                "description": "Unique identifier for this quality metric"
            },
            "task_id": {
                "type": "string",
                "description": "ID of the task being evaluated"
            },
            "metric_type": {
                "type": "string",
                "enum": ["performance", "accuracy", "efficiency", "reliability", "compliance"],
                "description": "Type of quality metric"
            },
            "criteria": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion_id": {
                            "type": "string",
                            "description": "Identifier for the criterion"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the criterion"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of what is being measured"
                        },
                        "weight": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Weight of this criterion in overall quality"
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
                            },
                            "required": ["min", "target"]
                        }
                    },
                    "required": ["criterion_id", "name", "description", "weight"]
                }
            },
            "measurements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion_id": {
                            "type": "string",
                            "description": "Reference to the criterion"
                        },
                        "value": {
                            "type": "number",
                            "description": "Measured value"
                        },
                        "timestamp": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When the measurement was taken"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["below_threshold", "meets_threshold", "exceeds_threshold"],
                            "description": "Status relative to threshold"
                        }
                    },
                    "required": ["criterion_id", "value", "timestamp", "status"]
                }
            },
            "aggregated_scores": {
                "type": "object",
                "properties": {
                    "overall_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Overall quality score"
                    },
                    "dimension_scores": {
                        "type": "object",
                        "description": "Scores broken down by dimension"
                    },
                    "trend": {
                        "type": "string",
                        "enum": ["improving", "stable", "declining"],
                        "description": "Quality trend over time"
                    }
                },
                "required": ["overall_score"]
            },
            "validation_results": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "validator_id": {
                            "type": "string",
                            "description": "ID of the validator"
                        },
                        "result": {
                            "type": "boolean",
                            "description": "Validation result"
                        },
                        "findings": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "severity": {
                                        "type": "string",
                                        "enum": ["info", "warning", "error"],
                                        "description": "Severity of the finding"
                                    },
                                    "message": {
                                        "type": "string",
                                        "description": "Description of the finding"
                                    }
                                },
                                "required": ["severity", "message"]
                            }
                        }
                    },
                    "required": ["validator_id", "result"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "evaluator": {
                        "type": "string",
                        "description": "ID of the entity performing evaluation"
                    },
                    "evaluation_method": {
                        "type": "string",
                        "description": "Method used for evaluation"
                    },
                    "confidence_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in the quality assessment"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes about quality evaluation"
                    }
                }
            }
        },
        "required": ["timestamp", "metric_id", "task_id", "metric_type", "criteria", "measurements"]
    }
) 