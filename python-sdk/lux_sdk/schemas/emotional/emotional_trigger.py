"""
EmotionalTriggerSchema

This schema represents emotional triggers and responses in an agent,
including the trigger source, emotional response, and intensity.
"""

from lux_sdk.signals import SignalSchema

EmotionalTriggerSchema = SignalSchema(
    name="emotional_trigger",
    version="1.0",
    description="Schema for representing emotional triggers and responses",
    schema={
        "type": "object",
        "properties": {
            "trigger_id": {"type": "string"},
            "timestamp": {"type": "string", "format": "date-time"},
            "source": {
                "type": "object",
                "properties": {
                    "type": {"type": "string"},  # e.g., "event", "interaction", "memory"
                    "identifier": {"type": "string"},
                    "context": {"type": "string"}
                },
                "required": ["type", "identifier", "context"]
            },
            "response": {
                "type": "object",
                "properties": {
                    "emotion": {"type": "string"},
                    "intensity": {
                        "type": "number",
                        "minimum": 0.0,
                        "maximum": 1.0
                    },
                    "valence": {
                        "type": "string",
                        "enum": ["positive", "negative", "neutral"]
                    }
                },
                "required": ["emotion", "intensity", "valence"]
            },
            "duration": {
                "type": "integer",
                "minimum": 0,
                "description": "Duration of emotional response in seconds"
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "notes": {"type": "string"}
                }
            }
        },
        "required": ["trigger_id", "timestamp", "source", "response", "duration"]
    }
) 