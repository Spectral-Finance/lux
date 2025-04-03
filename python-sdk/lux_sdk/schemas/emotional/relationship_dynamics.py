"""
Relationship Dynamics Schema

This schema represents the emotional dynamics and patterns of interaction
between agents in a relationship context, including emotional bonds,
communication patterns, and relationship health indicators.
"""

from lux_sdk.signals import SignalSchema

RelationshipDynamicsSchema = SignalSchema({
    "type": "object",
    "properties": {
        "timestamp": {
            "type": "string",
            "format": "date-time"
        },
        "relationship_id": {
            "type": "string",
            "description": "Unique identifier for the relationship dynamic"
        },
        "participants": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "agent_id": {
                        "type": "string",
                        "description": "Identifier for the participating agent"
                    },
                    "role": {
                        "type": "string",
                        "description": "Role of the agent in the relationship"
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
                "required": ["agent_id", "role", "emotional_state"]
            }
        },
        "interaction_patterns": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "pattern_type": {
                        "type": "string",
                        "description": "Type of interaction pattern observed"
                    },
                    "frequency": {
                        "type": "number",
                        "description": "Frequency of the pattern occurrence"
                    },
                    "impact": {
                        "type": "string",
                        "enum": ["positive", "neutral", "negative"],
                        "description": "Impact of the pattern on relationship"
                    }
                },
                "required": ["pattern_type", "frequency", "impact"]
            }
        },
        "relationship_health": {
            "type": "object",
            "properties": {
                "trust_level": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Level of trust between participants"
                },
                "communication_quality": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Quality of communication"
                },
                "emotional_safety": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Level of emotional safety"
                }
            },
            "required": ["trust_level", "communication_quality", "emotional_safety"]
        },
        "metadata": {
            "type": "object",
            "properties": {
                "context": {
                    "type": "string",
                    "description": "Context of the relationship"
                },
                "duration": {
                    "type": "string",
                    "description": "Duration of the relationship"
                },
                "last_updated": {
                    "type": "string",
                    "format": "date-time"
                }
            }
        }
    },
    "required": ["timestamp", "relationship_id", "participants", "relationship_health"]
}) 