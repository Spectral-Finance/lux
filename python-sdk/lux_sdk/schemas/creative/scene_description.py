"""
Scene Description Schema

This schema represents scene descriptions and settings,
including location, atmosphere, and action elements.
"""

from lux_sdk.signals import SignalSchema

SceneDescriptionSchema = SignalSchema(
    name="scene_description",
    version="1.0",
    description="Schema for scene descriptions and settings",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "scene_id": {
                "type": "string",
                "description": "Unique identifier for this scene"
            },
            "title": {
                "type": "string",
                "description": "Scene title"
            },
            "setting": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "Physical location"
                    },
                    "time": {
                        "type": "object",
                        "properties": {
                            "period": {"type": "string"},
                            "time_of_day": {"type": "string"},
                            "duration": {"type": "string"}
                        }
                    },
                    "weather": {
                        "type": "string",
                        "description": "Weather conditions"
                    }
                },
                "required": ["location"]
            },
            "atmosphere": {
                "type": "object",
                "properties": {
                    "mood": {
                        "type": "string",
                        "description": "Overall mood"
                    },
                    "lighting": {
                        "type": "string",
                        "description": "Lighting conditions"
                    },
                    "sensory_details": {
                        "type": "object",
                        "properties": {
                            "visual": {
                                "type": "array",
                                "items": {"type": "string"}
                            },
                            "auditory": {
                                "type": "array",
                                "items": {"type": "string"}
                            },
                            "olfactory": {
                                "type": "array",
                                "items": {"type": "string"}
                            }
                        }
                    }
                }
            },
            "characters": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "character_id": {
                            "type": "string",
                            "description": "Reference to character"
                        },
                        "state": {
                            "type": "string",
                            "description": "Character's state in scene"
                        },
                        "position": {
                            "type": "string",
                            "description": "Character's position in scene"
                        }
                    },
                    "required": ["character_id"]
                }
            },
            "action": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "sequence": {
                            "type": "integer",
                            "description": "Order in scene"
                        },
                        "description": {
                            "type": "string",
                            "description": "Action description"
                        },
                        "characters_involved": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Characters involved in action"
                        }
                    },
                    "required": ["sequence", "description"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the scene"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the scene"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": ["timestamp", "scene_id", "title", "setting"]
    }
) 