"""
DialogueState Schema

This schema defines the structure for representing the current state of a dialogue,
including conversation history, speaker turns, and dialogue context.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "dialogue_id": "conv_20240320_153000",
    "current_turn": {
        "speaker_id": "user_123",
        "utterance": "What's the weather like today?",
        "intent": "weather_query",
        "confidence": 0.95,
        "timestamp": "2024-03-20T15:30:00Z"
    },
    "context": {
        "topic": "weather",
        "location": "San Francisco",
        "turn_count": 3,
        "active_entities": ["location", "time", "weather_condition"]
    },
    "history": [
        {
            "speaker_id": "agent_456",
            "utterance": "Hello! How can I help you today?",
            "intent": "greeting",
            "timestamp": "2024-03-20T15:29:30Z"
        }
    ],
    "metadata": {
        "language": "en",
        "channel": "text",
        "session_id": "sess_789"
    }
}
```
"""

from lux_sdk.signals import SignalSchema

DialogueStateSchema = SignalSchema(
    name="dialogue_state",
    version="1.0",
    description="Schema for representing dialogue state and conversation flow",
    schema={
        "type": "object",
        "required": ["timestamp", "dialogue_id", "current_turn", "context", "metadata"],
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "Current state timestamp"
            },
            "dialogue_id": {
                "type": "string",
                "description": "Unique dialogue identifier"
            },
            "current_turn": {
                "type": "object",
                "required": ["speaker_id", "utterance", "timestamp"],
                "properties": {
                    "speaker_id": {
                        "type": "string",
                        "description": "Current speaker identifier"
                    },
                    "utterance": {
                        "type": "string",
                        "description": "Current utterance text"
                    },
                    "intent": {
                        "type": "string",
                        "description": "Detected intent"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Intent confidence"
                    },
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Turn timestamp"
                    }
                }
            },
            "context": {
                "type": "object",
                "required": ["topic", "turn_count"],
                "properties": {
                    "topic": {
                        "type": "string",
                        "description": "Current conversation topic"
                    },
                    "turn_count": {
                        "type": "integer",
                        "minimum": 0,
                        "description": "Number of turns"
                    },
                    "active_entities": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Currently relevant entities"
                    }
                }
            },
            "history": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["speaker_id", "utterance", "timestamp"],
                    "properties": {
                        "speaker_id": {
                            "type": "string",
                            "description": "Speaker identifier"
                        },
                        "utterance": {
                            "type": "string",
                            "description": "Utterance text"
                        },
                        "intent": {
                            "type": "string",
                            "description": "Detected intent"
                        },
                        "timestamp": {
                            "type": "string",
                            "format": "date-time",
                            "description": "Utterance timestamp"
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "required": ["language", "channel", "session_id"],
                "properties": {
                    "language": {
                        "type": "string",
                        "description": "Conversation language"
                    },
                    "channel": {
                        "type": "string",
                        "description": "Communication channel"
                    },
                    "session_id": {
                        "type": "string",
                        "description": "Session identifier"
                    }
                }
            }
        },
        "additionalProperties": False
    }
) 