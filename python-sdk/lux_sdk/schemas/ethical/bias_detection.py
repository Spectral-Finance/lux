"""
Bias Detection Schema

This schema defines the structure for detecting and analyzing biases in systems,
processes, and decision-making frameworks.
"""

from lux_sdk.signals import SignalSchema

BiasDetectionSchema = SignalSchema(
    name="bias_detection",
    version="1.0",
    description="Schema for detecting and analyzing potential biases",
    schema={
        "type": "object",
        "description": "Schema for detecting and analyzing potential biases",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the bias detection was performed"
            },
            "detection_id": {
                "type": "string",
                "description": "Unique identifier for this bias detection analysis"
            },
            "system_context": {
                "type": "object",
                "description": "Context of the system or process being analyzed",
                "properties": {
                    "name": {"type": "string"},
                    "domain": {"type": "string"},
                    "purpose": {"type": "string"}
                },
                "required": ["name", "domain", "purpose"]
            },
            "bias_types": {
                "type": "array",
                "description": "Types of biases being analyzed",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": [
                                "algorithmic",
                                "data",
                                "cognitive",
                                "social",
                                "cultural",
                                "institutional",
                                "sampling",
                                "measurement",
                                "other"
                            ]
                        },
                        "description": {"type": "string"},
                        "potential_impact": {"type": "string"}
                    },
                    "required": ["type", "description"]
                }
            },
            "analysis_methods": {
                "type": "array",
                "description": "Methods used to detect and analyze biases",
                "items": {
                    "type": "object",
                    "properties": {
                        "method": {"type": "string"},
                        "parameters": {"type": "object"},
                        "confidence_level": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1
                        }
                    },
                    "required": ["method", "confidence_level"]
                }
            },
            "findings": {
                "type": "array",
                "description": "Results of the bias detection analysis",
                "items": {
                    "type": "object",
                    "properties": {
                        "bias_type": {"type": "string"},
                        "severity": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"]
                        },
                        "evidence": {"type": "string"},
                        "affected_groups": {
                            "type": "array",
                            "items": {"type": "string"}
                        },
                        "recommendations": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    },
                    "required": ["bias_type", "severity", "evidence"]
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the bias detection process",
                "properties": {
                    "analyst": {"type": "string"},
                    "analysis_date": {"type": "string", "format": "date-time"},
                    "methodology_version": {"type": "string"},
                    "tools_used": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "review_status": {
                        "type": "string",
                        "enum": ["pending", "in_review", "approved", "rejected"]
                    }
                },
                "required": ["analyst", "analysis_date", "methodology_version"]
            }
        },
        "required": [
            "timestamp",
            "detection_id",
            "system_context",
            "bias_types",
            "analysis_methods",
            "findings",
            "metadata"
        ]
    }
) 