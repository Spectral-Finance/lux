"""
MetacognitionReportSchema

This schema represents an agent's metacognitive processes, including self-awareness
of its own thinking, learning strategies, and cognitive performance.
"""

from lux_sdk.signals import SignalSchema

MetacognitionReportSchema = SignalSchema(
    name="metacognition_report",
    version="1.0",
    description="Schema for representing an agent's metacognitive processes and self-awareness",
    schema={
        "type": "object",
        "properties": {
            "report_id": {"type": "string"},
            "timestamp": {"type": "string", "format": "date-time"},
            "cognitive_state": {
                "type": "object",
                "properties": {
                    "awareness_level": {
                        "type": "number",
                        "minimum": 0.0,
                        "maximum": 1.0,
                        "description": "Level of self-awareness from 0.0 (none) to 1.0 (full)"
                    },
                    "current_strategy": {"type": "string"},
                    "effectiveness": {
                        "type": "number",
                        "minimum": 0.0,
                        "maximum": 1.0
                    }
                },
                "required": ["awareness_level", "current_strategy", "effectiveness"]
            },
            "insights": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string"},
                        "description": {"type": "string"},
                        "confidence": {
                            "type": "number",
                            "minimum": 0.0,
                            "maximum": 1.0
                        }
                    },
                    "required": ["type", "description", "confidence"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "context": {"type": "string"},
                    "related_tasks": {"type": "array", "items": {"type": "string"}}
                }
            }
        },
        "required": ["report_id", "timestamp", "cognitive_state"]
    }
) 