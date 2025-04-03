"""
Data Schema Definition

This schema represents the structure and properties of data schemas,
including field definitions, relationships, and validation rules.
"""

from lux_sdk.signals import SignalSchema

DataSchemaDefinition = SignalSchema(
    name="data_schema",
    version="1.0",
    description="Schema for defining data structures, relationships, and validation rules",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "schema_id": {
                "type": "string",
                "description": "Unique identifier for this schema"
            },
            "name": {
                "type": "string",
                "description": "Name of the schema"
            },
            "version": {
                "type": "string",
                "description": "Version of the schema"
            },
            "description": {
                "type": "string",
                "description": "Description of what this schema represents"
            },
            "fields": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "Name of the field"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["string", "number", "integer", "boolean", "array", "object", "date", "datetime", "binary"],
                            "description": "Data type of the field"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the field"
                        },
                        "required": {
                            "type": "boolean",
                            "description": "Whether this field is required"
                        },
                        "constraints": {
                            "type": "object",
                            "properties": {
                                "min_length": {
                                    "type": "integer",
                                    "description": "Minimum length for string fields"
                                },
                                "max_length": {
                                    "type": "integer",
                                    "description": "Maximum length for string fields"
                                },
                                "pattern": {
                                    "type": "string",
                                    "description": "Regex pattern for validation"
                                },
                                "minimum": {
                                    "type": "number",
                                    "description": "Minimum value for numeric fields"
                                },
                                "maximum": {
                                    "type": "number",
                                    "description": "Maximum value for numeric fields"
                                },
                                "enum": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "List of allowed values"
                                }
                            }
                        },
                        "default_value": {
                            "description": "Default value for the field"
                        }
                    },
                    "required": ["name", "type"]
                }
            },
            "relationships": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "Name of the relationship"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["one_to_one", "one_to_many", "many_to_one", "many_to_many"],
                            "description": "Type of relationship"
                        },
                        "source_field": {
                            "type": "string",
                            "description": "Field in this schema"
                        },
                        "target_schema": {
                            "type": "string",
                            "description": "Referenced schema"
                        },
                        "target_field": {
                            "type": "string",
                            "description": "Field in target schema"
                        }
                    },
                    "required": ["name", "type", "source_field", "target_schema", "target_field"]
                }
            },
            "validation_rules": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "rule_id": {
                            "type": "string",
                            "description": "Identifier for the validation rule"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of what the rule validates"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["format", "range", "dependency", "custom"],
                            "description": "Type of validation rule"
                        },
                        "expression": {
                            "type": "string",
                            "description": "Validation expression or logic"
                        },
                        "error_message": {
                            "type": "string",
                            "description": "Message to display when validation fails"
                        }
                    },
                    "required": ["rule_id", "type", "expression"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_at": {
                        "type": "string",
                        "format": "date-time"
                    },
                    "updated_at": {
                        "type": "string",
                        "format": "date-time"
                    },
                    "created_by": {
                        "type": "string"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "schema_id", "name", "version", "fields"]
    }
) 