"""
Data Schema Definition

This schema defines the structure for data schemas,
including field definitions, relationships, and validation rules.
"""

from lux_sdk.signals import SignalSchema

DataSchemaSchema = SignalSchema(
    name="data_schema",
    version="1.0",
    description="Schema for defining data schemas and their properties",
    schema={
        "type": "object",
        "description": "Schema for defining data schemas and their properties",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the schema was created or last modified"
            },
            "schema_id": {
                "type": "string",
                "description": "Unique identifier for this schema definition"
            },
            "name": {
                "type": "string",
                "description": "Name of the schema"
            },
            "version": {
                "type": "string",
                "description": "Version of the schema"
            },
            "fields": {
                "type": "array",
                "description": "Field definitions for the schema",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "type": {
                            "type": "string",
                            "enum": [
                                "string",
                                "number",
                                "integer",
                                "boolean",
                                "array",
                                "object",
                                "date",
                                "datetime",
                                "binary",
                                "null"
                            ]
                        },
                        "description": {"type": "string"},
                        "required": {"type": "boolean"},
                        "default": {"type": "string"},
                        "constraints": {
                            "type": "object",
                            "properties": {
                                "min_length": {"type": "integer"},
                                "max_length": {"type": "integer"},
                                "pattern": {"type": "string"},
                                "enum": {
                                    "type": "array",
                                    "items": {"type": "string"}
                                },
                                "minimum": {"type": "number"},
                                "maximum": {"type": "number"}
                            }
                        }
                    },
                    "required": ["name", "type"]
                }
            },
            "relationships": {
                "type": "array",
                "description": "Relationships between fields or with other schemas",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": ["one_to_one", "one_to_many", "many_to_one", "many_to_many"]
                        },
                        "from_field": {"type": "string"},
                        "to_schema": {"type": "string"},
                        "to_field": {"type": "string"},
                        "description": {"type": "string"}
                    },
                    "required": ["type", "from_field", "to_schema", "to_field"]
                }
            },
            "validation_rules": {
                "type": "array",
                "description": "Rules for validating data against the schema",
                "items": {
                    "type": "object",
                    "properties": {
                        "rule_type": {
                            "type": "string",
                            "enum": ["format", "range", "uniqueness", "custom"]
                        },
                        "field": {"type": "string"},
                        "condition": {"type": "string"},
                        "error_message": {"type": "string"}
                    },
                    "required": ["rule_type", "field", "condition"]
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the schema",
                "properties": {
                    "author": {"type": "string"},
                    "created_at": {"type": "string", "format": "date-time"},
                    "modified_at": {"type": "string", "format": "date-time"},
                    "description": {"type": "string"},
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"}
                    }
                },
                "required": ["author", "created_at"]
            }
        },
        "required": [
            "timestamp",
            "schema_id",
            "name",
            "version",
            "fields",
            "metadata"
        ]
    }) 