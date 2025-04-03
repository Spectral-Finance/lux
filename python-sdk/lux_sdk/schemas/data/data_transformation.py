"""
Data Transformation Schema

This schema represents data transformation operations, including input/output specifications,
transformation rules, and validation criteria.
"""

from lux_sdk.signals import SignalSchema

DataTransformationSchema = SignalSchema(
    name="data_transformation",
    version="1.0",
    description="Schema for tracking data transformation operations and their metadata",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "transformation_id": {
                "type": "string",
                "description": "Unique identifier for this transformation"
            },
            "name": {
                "type": "string",
                "description": "Human-readable name for the transformation"
            },
            "input_specification": {
                "type": "object",
                "properties": {
                    "data_source": {
                        "type": "string",
                        "description": "Source of the input data"
                    },
                    "schema": {
                        "type": "object",
                        "description": "Schema definition of input data"
                    },
                    "constraints": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "field": {
                                    "type": "string",
                                    "description": "Field name"
                                },
                                "condition": {
                                    "type": "string",
                                    "description": "Constraint condition"
                                }
                            },
                            "required": ["field", "condition"]
                        }
                    }
                },
                "required": ["data_source", "schema"]
            },
            "transformation_rules": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "rule_id": {
                            "type": "string",
                            "description": "Identifier for the rule"
                        },
                        "operation": {
                            "type": "string",
                            "enum": ["map", "filter", "aggregate", "join", "split", "merge", "custom"],
                            "description": "Type of transformation operation"
                        },
                        "parameters": {
                            "type": "object",
                            "description": "Operation-specific parameters"
                        },
                        "dependencies": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "IDs of rules this rule depends on"
                            }
                        }
                    },
                    "required": ["rule_id", "operation", "parameters"]
                }
            },
            "output_specification": {
                "type": "object",
                "properties": {
                    "data_destination": {
                        "type": "string",
                        "description": "Destination for transformed data"
                    },
                    "schema": {
                        "type": "object",
                        "description": "Schema definition of output data"
                    },
                    "format": {
                        "type": "string",
                        "enum": ["csv", "json", "parquet", "avro", "custom"],
                        "description": "Output data format"
                    }
                },
                "required": ["data_destination", "schema"]
            },
            "validation": {
                "type": "object",
                "properties": {
                    "quality_checks": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "check_id": {
                                    "type": "string",
                                    "description": "Identifier for the check"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["completeness", "accuracy", "consistency", "validity"],
                                    "description": "Type of quality check"
                                },
                                "criteria": {
                                    "type": "string",
                                    "description": "Check criteria"
                                }
                            },
                            "required": ["check_id", "type", "criteria"]
                        }
                    },
                    "thresholds": {
                        "type": "object",
                        "properties": {
                            "error_threshold": {
                                "type": "number",
                                "description": "Maximum allowed error rate"
                            },
                            "warning_threshold": {
                                "type": "number",
                                "description": "Warning threshold for error rate"
                            }
                        }
                    }
                }
            },
            "execution": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["pending", "running", "completed", "failed"],
                        "description": "Current execution status"
                    },
                    "start_time": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When execution started"
                    },
                    "end_time": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When execution completed"
                    },
                    "error_log": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time"
                                },
                                "error_type": {
                                    "type": "string",
                                    "description": "Type of error"
                                },
                                "message": {
                                    "type": "string",
                                    "description": "Error message"
                                }
                            },
                            "required": ["timestamp", "error_type", "message"]
                        }
                    }
                },
                "required": ["status"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {
                        "type": "string",
                        "description": "ID of transformation creator"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the transformation"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    },
                    "description": {
                        "type": "string",
                        "description": "Detailed description of the transformation"
                    }
                }
            }
        },
        "required": ["timestamp", "transformation_id", "name", "input_specification", "transformation_rules", "output_specification"]
    }
) 