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
                "required": true,
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
                "required": ["timestamp", "schema_id", "namespace", "schema_definition", "fields"],
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
                        "required": ["name", "description", "version"],
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
                        }
                    },
                    "fields": {
                        "type": "array",
                        "description": "Field definitions",
                        "items": {
                            "type": "object",
                            "required": ["field_id", "name", "type", "description"],
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
                                "required": {
                                    "type": "boolean",
                                    "description": "Whether the field is required"
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
                                },
                                "metadata": {
                                    "type": "object",
                                    "description": "Field metadata",
                                    "properties": {
                                        "source": {
                                            "type": "string",
                                            "description": "Data source"
                                        },
                                        "sensitivity": {
                                            "type": "string",
                                            "enum": ["public", "internal", "confidential", "restricted"],
                                            "description": "Data sensitivity level"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "relationships": {
                        "type": "array",
                        "description": "Schema relationships",
                        "items": {
                            "type": "object",
                            "required": ["relationship_id", "type", "source_field", "target_schema", "target_field"],
                            "properties": {
                                "relationship_id": {
                                    "type": "string",
                                    "description": "Relationship identifier"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["one_to_one", "one_to_many", "many_to_one", "many_to_many"],
                                    "description": "Relationship type"
                                },
                                "source_field": {
                                    "type": "string",
                                    "description": "Source field name"
                                },
                                "target_schema": {
                                    "type": "string",
                                    "description": "Target schema name"
                                },
                                "target_field": {
                                    "type": "string",
                                    "description": "Target field name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Relationship description"
                                },
                                "constraints": {
                                    "type": "object",
                                    "description": "Relationship constraints",
                                    "properties": {
                                        "cascade_delete": {
                                            "type": "boolean",
                                            "description": "Whether to cascade deletes"
                                        },
                                        "on_update": {
                                            "type": "string",
                                            "enum": ["cascade", "restrict", "set_null"],
                                            "description": "Update behavior"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "validation_rules": {
                        "type": "array",
                        "description": "Data validation rules",
                        "items": {
                            "type": "object",
                            "required": ["rule_id", "name", "description", "condition"],
                            "properties": {
                                "rule_id": {
                                    "type": "string",
                                    "description": "Rule identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Rule name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Rule description"
                                },
                                "condition": {
                                    "type": "string",
                                    "description": "Validation condition"
                                },
                                "severity": {
                                    "type": "string",
                                    "enum": ["info", "warning", "error"],
                                    "description": "Rule severity"
                                },
                                "message": {
                                    "type": "string",
                                    "description": "Validation message"
                                }
                            }
                        }
                    },
                    "compatibility": {
                        "type": "object",
                        "description": "Schema compatibility information",
                        "properties": {
                            "backward_compatible": {
                                "type": "boolean",
                                "description": "Backward compatibility status"
                            },
                            "forward_compatible": {
                                "type": "boolean",
                                "description": "Forward compatibility status"
                            },
                            "breaking_changes": {
                                "type": "array",
                                "description": "Breaking changes",
                                "items": {"type": "string"}
                            },
                            "deprecated_fields": {
                                "type": "array",
                                "description": "Deprecated fields",
                                "items": {"type": "string"}
                            },
                            "supported_versions": {
                                "type": "array",
                                "description": "Supported schema versions",
                                "items": {"type": "string"}
                            },
                            "migration_scripts": {
                                "type": "object",
                                "description": "Version migration scripts",
                                "additionalProperties": {"type": "string"}
                            }
                        }
                    },
                    "documentation": {
                        "type": "object",
                        "description": "Schema documentation",
                        "properties": {
                            "description": {
                                "type": "string",
                                "description": "Detailed documentation"
                            },
                            "usage_examples": {
                                "type": "array",
                                "description": "Usage examples",
                                "items": {
                                    "type": "object",
                                    "required": ["title", "code"],
                                    "properties": {
                                        "title": {
                                            "type": "string",
                                            "description": "Example title"
                                        },
                                        "code": {
                                            "type": "string",
                                            "description": "Example code"
                                        },
                                        "description": {
                                            "type": "string",
                                            "description": "Example description"
                                        }
                                    }
                                }
                            },
                            "changelog": {
                                "type": "array",
                                "description": "Schema changelog",
                                "items": {
                                    "type": "object",
                                    "required": ["version", "date", "changes"],
                                    "properties": {
                                        "version": {
                                            "type": "string",
                                            "description": "Version number"
                                        },
                                        "date": {
                                            "type": "string",
                                            "format": "date",
                                            "description": "Change date"
                                        },
                                        "changes": {
                                            "type": "array",
                                            "description": "List of changes",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            },
                            "field_descriptions": {
                                "type": "object",
                                "description": "Detailed field descriptions",
                                "additionalProperties": {"type": "string"}
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the schema",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Schema creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Schema version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "deprecated"],
                                "description": "Schema status"
                            },
                            "review_status": {
                                "type": "string",
                                "enum": ["pending", "in_review", "approved", "rejected"],
                                "description": "Review status"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {"type": "string"}
                            }
                        }
                    }
                }
            }
        ) 