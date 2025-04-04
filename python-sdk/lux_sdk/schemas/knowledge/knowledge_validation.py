"""
KnowledgeValidationSchema

This schema represents the validation of knowledge claims and assertions,
including confidence levels, sources, and verification methods.
"""

from lux_sdk.signals import SignalSchema

KnowledgeValidationSchema = SignalSchema(
    name="knowledge_validation",
    version="1.0",
    description="Schema for representing knowledge validation processes and results",
    schema={
        "type": "object",
        "properties": {
            "validation_id": {"type": "string"},
            "timestamp": {"type": "string", "format": "date-time"},
            "claim": {
                "type": "object",
                "properties": {
                    "statement": {"type": "string"},
                    "domain": {"type": "string"},
                    "source": {"type": "string"}
                },
                "required": ["statement", "domain", "source"]
            },
            "validation": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["verified", "disputed", "unverified"]
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0.0,
                        "maximum": 1.0
                    },
                    "method": {"type": "string"}
                },
                "required": ["status", "confidence", "method"]
            },
            "evidence": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string"},
                        "reference": {"type": "string"},
                        "reliability": {
                            "type": "number",
                            "minimum": 0.0,
                            "maximum": 1.0
                        }
                    },
                    "required": ["type", "reference", "reliability"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "reviewer": {"type": "string"},
                    "notes": {"type": "string"},
                    "tags": {"type": "array", "items": {"type": "string"}}
                }
            }
        },
        "required": ["validation_id", "timestamp", "claim", "validation"]
    }
) 