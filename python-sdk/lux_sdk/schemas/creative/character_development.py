"""
Character Development Schema

This schema represents character development and progression,
including personality traits, relationships, and story arc.
"""

from lux_sdk.signals import SignalSchema

CharacterDevelopmentSchema = SignalSchema(
    name="character_development",
    version="1.0",
    description="Schema for character development and progression",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "character_id": {
                "type": "string",
                "description": "Unique identifier for this character"
            },
            "name": {
                "type": "string",
                "description": "Character name"
            },
            "role": {
                "type": "string",
                "enum": ["protagonist", "antagonist", "supporting", "mentor", "foil"],
                "description": "Character's role in the story"
            },
            "attributes": {
                "type": "object",
                "properties": {
                    "physical": {
                        "type": "object",
                        "properties": {
                            "age": {"type": "integer"},
                            "appearance": {"type": "string"},
                            "distinguishing_features": {
                                "type": "array",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "personality": {
                        "type": "object",
                        "properties": {
                            "traits": {
                                "type": "array",
                                "items": {"type": "string"}
                            },
                            "motivations": {
                                "type": "array",
                                "items": {"type": "string"}
                            },
                            "fears": {
                                "type": "array",
                                "items": {"type": "string"}
                            }
                        }
                    }
                }
            },
            "relationships": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "character_id": {
                            "type": "string",
                            "description": "ID of related character"
                        },
                        "type": {
                            "type": "string",
                            "description": "Type of relationship"
                        },
                        "dynamics": {
                            "type": "string",
                            "description": "Description of relationship dynamics"
                        }
                    },
                    "required": ["character_id", "type"]
                }
            },
            "development": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "stage": {
                            "type": "string",
                            "description": "Development stage"
                        },
                        "changes": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "aspect": {
                                        "type": "string",
                                        "description": "What changes"
                                    },
                                    "from": {
                                        "type": "string",
                                        "description": "Initial state"
                                    },
                                    "to": {
                                        "type": "string",
                                        "description": "Final state"
                                    },
                                    "catalyst": {
                                        "type": "string",
                                        "description": "What triggers the change"
                                    }
                                },
                                "required": ["aspect", "from", "to"]
                            }
                        }
                    },
                    "required": ["stage", "changes"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the character"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the character"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": ["timestamp", "character_id", "name", "role", "attributes"]
    }
) 