"""
Pragmatic Context Schema

This schema represents pragmatic context in natural language processing,
including discourse context, speaker intentions, and situational factors.
"""

from lux_sdk.signals import SignalSchema

PragmaticContextSchema = SignalSchema(
    name="pragmatic_context",
    version="1.0",
    description="Schema for pragmatic context in natural language processing",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "context_id": {
                "type": "string",
                "description": "Unique identifier for this pragmatic context"
            },
            "discourse_context": {
                "type": "object",
                "properties": {
                    "conversation_id": {
                        "type": "string",
                        "description": "Identifier for the conversation"
                    },
                    "turn_number": {
                        "type": "integer",
                        "minimum": 0,
                        "description": "Turn number in conversation"
                    },
                    "participants": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "participant_id": {
                                    "type": "string",
                                    "description": "Participant identifier"
                                },
                                "role": {
                                    "type": "string",
                                    "description": "Role in conversation"
                                },
                                "speaking_status": {
                                    "type": "string",
                                    "enum": ["speaker", "addressee", "observer"],
                                    "description": "Current speaking status"
                                }
                            },
                            "required": ["participant_id", "role"]
                        }
                    },
                    "topic_history": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "topic": {
                                    "type": "string",
                                    "description": "Conversation topic"
                                },
                                "start_turn": {
                                    "type": "integer",
                                    "description": "Turn where topic started"
                                },
                                "end_turn": {
                                    "type": "integer",
                                    "description": "Turn where topic ended"
                                }
                            },
                            "required": ["topic", "start_turn"]
                        }
                    }
                },
                "required": ["conversation_id", "participants"]
            },
            "speaker_intent": {
                "type": "object",
                "properties": {
                    "primary_intent": {
                        "type": "string",
                        "enum": [
                            "inform",
                            "request",
                            "command",
                            "express_emotion",
                            "social_bonding",
                            "clarify",
                            "acknowledge",
                            "other"
                        ],
                        "description": "Primary intention of the speaker"
                    },
                    "secondary_intents": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Secondary intentions"
                        }
                    },
                    "speech_acts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of speech act"
                                },
                                "force": {
                                    "type": "string",
                                    "enum": ["direct", "indirect"],
                                    "description": "Illocutionary force"
                                },
                                "confidence": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Confidence in speech act classification"
                                }
                            },
                            "required": ["type", "force"]
                        }
                    }
                },
                "required": ["primary_intent"]
            },
            "situational_context": {
                "type": "object",
                "properties": {
                    "setting": {
                        "type": "object",
                        "properties": {
                            "location_type": {
                                "type": "string",
                                "description": "Type of location"
                            },
                            "time": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Time of interaction"
                            },
                            "environment": {
                                "type": "string",
                                "description": "Environmental context"
                            }
                        }
                    },
                    "social_context": {
                        "type": "object",
                        "properties": {
                            "formality_level": {
                                "type": "string",
                                "enum": ["formal", "semi_formal", "informal", "casual"],
                                "description": "Level of formality"
                            },
                            "power_dynamics": {
                                "type": "object",
                                "properties": {
                                    "relationship_type": {
                                        "type": "string",
                                        "description": "Type of relationship"
                                    },
                                    "hierarchy": {
                                        "type": "string",
                                        "enum": ["equal", "superior", "subordinate"],
                                        "description": "Hierarchical relationship"
                                    }
                                }
                            },
                            "cultural_factors": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "Relevant cultural factors"
                                }
                            }
                        }
                    }
                }
            },
            "reference_resolution": {
                "type": "object",
                "properties": {
                    "anaphora": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "reference": {
                                    "type": "string",
                                    "description": "Anaphoric reference"
                                },
                                "antecedent": {
                                    "type": "string",
                                    "description": "Resolved antecedent"
                                },
                                "confidence": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Resolution confidence"
                                }
                            },
                            "required": ["reference", "antecedent"]
                        }
                    },
                    "deixis": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "expression": {
                                    "type": "string",
                                    "description": "Deictic expression"
                                },
                                "referent": {
                                    "type": "string",
                                    "description": "Resolved referent"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["temporal", "spatial", "personal", "social"],
                                    "description": "Type of deixis"
                                }
                            },
                            "required": ["expression", "type"]
                        }
                    }
                }
            },
            "discourse_relations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": [
                                "cause",
                                "contrast",
                                "elaboration",
                                "temporal",
                                "condition",
                                "other"
                            ],
                            "description": "Type of discourse relation"
                        },
                        "arguments": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Related discourse segments"
                            }
                        },
                        "markers": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Discourse markers"
                            }
                        }
                    },
                    "required": ["type", "arguments"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "analysis_timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When context was analyzed"
                    },
                    "confidence_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Overall confidence in context analysis"
                    },
                    "source": {
                        "type": "string",
                        "description": "Source of context information"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "context_id",
            "discourse_context",
            "speaker_intent"
        ]
    }
) 