"""
OntologyMappingSchema

This schema represents mappings between different ontologies or knowledge structures,
including concept alignments, relationship mappings, and transformation rules.
"""

from lux_sdk.signals import SignalSchema

OntologyMappingSchema = SignalSchema(
    name="ontology_mapping",
    version="1.0",
    description="Schema for representing mappings between different ontologies or knowledge structures",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "mapping_id": {"type": "string", "required": True},
            "source_ontology": {
                "type": "object",
                "required": True,
                "properties": {
                    "id": {"type": "string", "required": True},
                    "name": {"type": "string", "required": True},
                    "version": {"type": "string", "required": True},
                    "namespace": {"type": "string", "required": True}
                }
            },
            "target_ontology": {
                "type": "object",
                "required": True,
                "properties": {
                    "id": {"type": "string", "required": True},
                    "name": {"type": "string", "required": True},
                    "version": {"type": "string", "required": True},
                    "namespace": {"type": "string", "required": True}
                }
            },
            "mappings": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "source_concept": {"type": "string", "required": True},
                        "target_concept": {"type": "string", "required": True},
                        "mapping_type": {
                            "type": "string",
                            "enum": ["exact", "broader", "narrower", "related"],
                            "required": True
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0.0,
                            "maximum": 1.0,
                            "required": True
                        },
                        "transformation_rules": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    }
                }
            },
            "validation": {
                "type": "object",
                "properties": {
                    "validated_by": {"type": "string"},
                    "validation_date": {"type": "string", "format": "date-time"},
                    "validation_score": {"type": "number", "minimum": 0.0, "maximum": 1.0},
                    "issues": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"},
                                "description": {"type": "string"},
                                "severity": {"type": "string", "enum": ["low", "medium", "high"]}
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {"type": "string"},
                    "creation_date": {"type": "string", "format": "date-time"},
                    "last_modified": {"type": "string", "format": "date-time"},
                    "description": {"type": "string"},
                    "tags": {"type": "array", "items": {"type": "string"}}
                }
            }
        }
    }
) 