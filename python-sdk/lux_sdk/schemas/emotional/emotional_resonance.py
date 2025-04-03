"""
Emotional Resonance Schema

This schema represents emotional resonance and synchronization between entities,
including emotional alignment, shared experiences, and mutual understanding.
"""

from lux_sdk.signals import SignalSchema

EmotionalResonanceSchema = SignalSchema(
    name="emotional_resonance",
    version="1.0",
    description="Schema for tracking emotional resonance and synchronization between entities",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "resonance_id": {
                "type": "string",
                "description": "Unique identifier for this resonance instance"
            },
            "participants": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "participant_id": {
                            "type": "string",
                            "description": "Identifier for the participant"
                        },
                        "emotional_state": {
                            "type": "object",
                            "properties": {
                                "primary_emotion": {
                                    "type": "string",
                                    "description": "Primary emotion being experienced"
                                },
                                "intensity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Intensity of the emotional state"
                                }
                            },
                            "required": ["primary_emotion", "intensity"]
                        }
                    },
                    "required": ["participant_id", "emotional_state"]
                }
            },
            "resonance_metrics": {
                "type": "object",
                "properties": {
                    "synchronization_level": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Level of emotional synchronization"
                    },
                    "mutual_understanding": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Degree of mutual emotional understanding"
                    },
                    "empathy_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Level of empathic connection"
                    }
                },
                "required": ["synchronization_level", "mutual_understanding"]
            },
            "interaction_context": {
                "type": "object",
                "properties": {
                    "setting": {
                        "type": "string",
                        "description": "Context or setting of the interaction"
                    },
                    "duration": {
                        "type": "integer",
                        "description": "Duration of interaction in seconds"
                    },
                    "communication_channel": {
                        "type": "string",
                        "enum": ["face_to_face", "video", "audio", "text", "mixed"],
                        "description": "Channel of communication"
                    }
                },
                "required": ["setting", "communication_channel"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "measurement_method": {
                        "type": "string",
                        "description": "Method used to measure emotional resonance"
                    },
                    "confidence_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in the resonance assessment"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional observations or context"
                    }
                }
            }
        },
        "required": ["timestamp", "resonance_id", "participants", "resonance_metrics"]
    }
) 