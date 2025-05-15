"""
AttentionFocusSchema

This schema represents the current focus and attention state of an agent,
including what it is attending to, the level of attention, and any distractions.
"""

from lux_sdk.signals import SignalSchema

AttentionFocusSchema = SignalSchema(
    name="attention_focus",
    version="1.0",
    description="Schema for representing an agent's current focus and attention state",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time"},
            "focus_id": {"type": "string"},
            "target": {
                "type": "object",
                "properties": {
                    "type": {"type": "string"},  # e.g., "task", "conversation", "environment"
                    "identifier": {"type": "string"},
                    "priority": {"type": "integer", "minimum": 1, "maximum": 10}
                },
                "required": ["type", "identifier", "priority"]
            },
            "attention_level": {
                "type": "number",
                "minimum": 0.0,
                "maximum": 1.0,
                "description": "Level of attention from 0.0 (completely distracted) to 1.0 (fully focused)"
            },
            "distractions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "source": {"type": "string"},
                        "impact": {"type": "number", "minimum": 0.0, "maximum": 1.0}
                    },
                    "required": ["source", "impact"]
                }
            },
            "duration": {
                "type": "integer",
                "minimum": 0,
                "description": "Duration of current focus in seconds"
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "context": {"type": "string"},
                    "notes": {"type": "string"},
                    "related_tasks": {"type": "array", "items": {"type": "string"}}
                }
            }
        },
        "required": ["timestamp", "focus_id", "target", "attention_level", "duration"]
    }
) 