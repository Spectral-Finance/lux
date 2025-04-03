"""
Schema for data schema definitions.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class DataSchema(SignalSchema):
    """Schema for representing data schema definitions.
    
    This schema defines the structure for representing data schemas, including field definitions,
    relationships, validation rules, compatibility information, and documentation.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "schema_id": "schema_20240403_153000",
            "namespace": "customer_data",
            "schema_definition": {
                "name": "Customer Profile Schema",
                "description": "Schema for customer profile data",
                "version": "1.0",
                "format": "json"
            },
            "fields": [{
                "field_id": "field_1",
                "name": "customer_id",
                "type": "string",
                "description": "Unique customer identifier",
                "constraints": {
                    "pattern": "^CUST_\\d{6}$",
                    "unique": true
                },
                "metadata": {
                    "source": "system_generated",
                    "sensitivity": "internal"
                }
            }],
            "relationships": [{
                "relationship_id": "rel_1",
                "type": "one_to_many",
                "source_field": "customer_id",
                "target_schema": "orders",
                "target_field": "customer_id",
                "description": "Customer's order history",
                "constraints": {
                    "cascade_delete": true,
                    "on_update": "cascade"
                }
            }],
            "validation_rules": [{
                "rule_id": "rule_1",
                "name": "Age Validation",
                "description": "Validate customer age is within legal range",
                "condition": "age >= 18 AND age <= 120",
                "severity": "error",
                "message": "Customer age must be between 18 and 120"
            }],
            "compatibility": {
                "backward_compatible": true,
                "forward_compatible": true,
                "breaking_changes": [],
                "deprecated_fields": [],
                "supported_versions": ["1.0", "1.1"],
                "migration_scripts": {
                    "1.0_to_1.1": "migration_script_v1_to_v1_1.sql"
                }
            },
            "documentation": {
                "description": "Detailed schema documentation",
                "usage_examples": [{
                    "title": "Create Customer Profile",
                    "code": "example_code_snippet",
                    "description": "Example of creating a new customer profile"
                }],
                "changelog": [{
                    "version": "1.1",
                    "date": "2024-04-03",
                    "changes": ["Added email verification field"]
                }],
                "field_descriptions": {
                    "customer_id": "Primary identifier for customer records",
                    "email": "Customer's primary email address"
                }
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "schema_admin",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "active",
                "review_status": "approved",
                "tags": ["customer", "profile", "core_schema"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="data_schema",
            version="1.0",
            description="Schema for representing data schema definitions",
            schema={
                "type": "object",
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the schema definition"
                    },
                    "schema_id": {
                        "type": "string",
                        "description": "Unique identifier for the schema"
                    },
                    "namespace": {
                        "type": "string",
                        "description": "Namespace or domain of the schema"
                    },
                    "schema_definition": {
                        "type": "object",
                        "description": "Core schema definition",
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Schema name"
                            },
                            "description": {
                                "type": "string",
                                "description": "Schema description"
                            },
                            "version": {
                                "type": "string",
                                "description": "Schema version"
                            },
                            "format": {
                                "type": "string",
                                "enum": ["json", "avro", "protobuf", "xml", "csv"],
                                "description": "Data format"
                            }
                        },
                        "required": ["name", "description", "version"]
                    },
                    "fields": {
                        "type": "array",
                        "description": "Field definitions",
                        "items": {
                            "type": "object",
                            "properties": {
                                "field_id": {
                                    "type": "string",
                                    "description": "Field identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Field name"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["string", "integer", "number", "boolean", "array", "object", "date", "datetime"],
                                    "description": "Field data type"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Field description"
                                },
                                "constraints": {
                                    "type": "object",
                                    "description": "Field constraints",
                                    "properties": {
                                        "pattern": {
                                            "type": "string",
                                            "description": "Regex pattern for validation"
                                        },
                                        "minimum": {
                                            "type": "number",
                                            "description": "Minimum value"
                                        },
                                        "maximum": {
                                            "type": "number",
                                            "description": "Maximum value"
                                        },
                                        "unique": {
                                            "type": "boolean",
                                            "description": "Whether values must be unique"
                                        },
                                        "enum": {
                                            "type": "array",
                                            "description": "Allowed values",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            },
                            "required": ["field_id", "name", "type", "description"]
                        }
                    }
                },
                "required": ["timestamp", "schema_id", "namespace", "schema_definition", "fields"]
            }
        ) 