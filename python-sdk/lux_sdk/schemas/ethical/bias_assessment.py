"""
Bias Detection Schema

This schema represents the assessment and documentation of potential biases
in systems, processes, or decisions, including identification, analysis,
and mitigation strategies.
"""

from lux_sdk.signals import SignalSchema

BiasDetectionSchema = SignalSchema(
    name="bias_detection",
    version="1.0",
    description="Schema for bias detection and mitigation planning",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "assessment_id": {
                "type": "string",
                "description": "Unique identifier for this bias assessment"
            },
            "project_id": {
                "type": "string",
                "description": "Reference to the associated project"
            },
            "scope": {
                "type": "object",
                "properties": {
                    "system_name": {
                        "type": "string",
                        "description": "Name of the system being assessed"
                    },
                    "components": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "List of components or subsystems being assessed"
                    },
                    "context": {
                        "type": "string",
                        "description": "Context in which the assessment is being performed"
                    }
                },
                "required": ["system_name", "context"]
            },
            "identified_biases": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "bias_id": {
                            "type": "string",
                            "description": "Unique identifier for this bias"
                        },
                        "type": {
                            "type": "string",
                            "enum": [
                                "selection_bias",
                                "sampling_bias",
                                "measurement_bias",
                                "algorithmic_bias",
                                "reporting_bias",
                                "confirmation_bias",
                                "cognitive_bias",
                                "social_bias",
                                "other"
                            ],
                            "description": "Type of bias identified"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed description of the bias"
                        },
                        "affected_groups": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Groups potentially affected by this bias"
                        },
                        "source": {
                            "type": "object",
                            "properties": {
                                "category": {
                                    "type": "string",
                                    "enum": ["data", "algorithm", "process", "human", "system", "other"],
                                    "description": "Category of bias source"
                                },
                                "details": {
                                    "type": "string",
                                    "description": "Detailed description of bias source"
                                }
                            },
                            "required": ["category"]
                        },
                        "severity": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "enum": ["critical", "high", "medium", "low"],
                                    "description": "Severity level of bias"
                                },
                                "justification": {
                                    "type": "string",
                                    "description": "Justification for severity rating"
                                }
                            },
                            "required": ["level"]
                        }
                    },
                    "required": ["bias_id", "type", "description", "source"]
                }
            },
            "mitigation_strategies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "strategy_id": {
                            "type": "string",
                            "description": "Unique identifier for this strategy"
                        },
                        "bias_id": {
                            "type": "string",
                            "description": "Reference to the bias being mitigated"
                        },
                        "approach": {
                            "type": "string",
                            "enum": ["prevention", "detection", "correction", "monitoring"],
                            "description": "Type of mitigation approach"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the mitigation strategy"
                        },
                        "implementation_status": {
                            "type": "string",
                            "enum": ["planned", "in_progress", "implemented", "evaluated"],
                            "description": "Status of strategy implementation"
                        },
                        "effectiveness_metrics": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "metric_name": {
                                        "type": "string",
                                        "description": "Name of the metric"
                                    },
                                    "description": {
                                        "type": "string",
                                        "description": "Description of what is being measured"
                                    },
                                    "target_value": {
                                        "type": "string",
                                        "description": "Target value or range for the metric"
                                    }
                                },
                                "required": ["metric_name", "description"]
                            }
                        }
                    },
                    "required": ["strategy_id", "bias_id", "approach", "description"]
                }
            },
            "testing_validation": {
                "type": "object",
                "properties": {
                    "test_cases": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "test_id": {
                                    "type": "string",
                                    "description": "Identifier for this test case"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the test case"
                                },
                                "methodology": {
                                    "type": "string",
                                    "description": "Testing methodology used"
                                },
                                "results": {
                                    "type": "string",
                                    "description": "Results of the test case"
                                }
                            },
                            "required": ["test_id", "description"]
                        }
                    },
                    "validation_methods": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Methods used to validate bias mitigation"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the assessment"
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
                        "description": "Version of the assessment"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "archived"],
                        "description": "Status of the assessment"
                    }
                }
            }
        },
        "required": ["timestamp", "assessment_id", "project_id", "scope", "identified_biases"]
    }
) 