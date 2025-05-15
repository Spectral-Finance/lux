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
            "timestamp": {"type": "string", "format": "date-time"},
            "mapping_id": {"type": "string"},
            "source_ontology": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "version": {"type": "string"},
                    "namespace": {"type": "string"}
                },
                "required": ["id", "name", "version", "namespace"]
            },
            "target_ontology": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "version": {"type": "string"},
                    "namespace": {"type": "string"}
                },
                "required": ["id", "name", "version", "namespace"]
            },
            "mappings": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "source_concept": {"type": "string"},
                        "target_concept": {"type": "string"},
                        "mapping_type": {
                            "type": "string",
                            "enum": ["exact", "broader", "narrower", "related"]
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0.0,
                            "maximum": 1.0
                        },
                        "transformation_rules": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    },
                    "required": ["source_concept", "target_concept", "mapping_type", "confidence"]
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
        },
        "required": ["timestamp", "mapping_id", "source_ontology", "target_ontology", "mappings"]
    }
) 