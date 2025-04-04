"""
Emotional Support Schema

This schema represents emotional support and well-being assessment,
including emotional states, support mechanisms, and intervention strategies.
"""

from lux_sdk.signals import SignalSchema

EmotionalSupportSchema = SignalSchema(
    name="emotional_support",
    version="1.0",
    description="Schema for emotional support and well-being assessment",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "support_id": {
                "type": "string",
                "description": "Unique identifier for this emotional support interaction"
            },
            "participant": {
                "type": "object",
                "properties": {
                    "participant_id": {
                        "type": "string",
                        "description": "Unique identifier for the participant"
                    },
                    "anonymous": {
                        "type": "boolean",
                        "description": "Whether the participant wishes to remain anonymous"
                    },
                    "preferences": {
                        "type": "object",
                        "properties": {
                            "communication_mode": {
                                "type": "string",
                                "enum": ["text", "voice", "video", "in_person"],
                                "description": "Preferred mode of communication"
                            },
                            "language": {
                                "type": "string",
                                "description": "Preferred language for communication"
                            },
                            "support_type": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "enum": ["listening", "advice", "resources", "professional_referral"]
                                },
                                "description": "Types of support preferred"
                            }
                        }
                    }
                },
                "required": ["participant_id"]
            },
            "emotional_state": {
                "type": "object",
                "properties": {
                    "primary_emotion": {
                        "type": "string",
                        "description": "Primary emotion being experienced"
                    },
                    "intensity": {
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 10,
                        "description": "Intensity level of the emotion"
                    },
                    "duration": {
                        "type": "string",
                        "description": "Duration of the emotional state"
                    },
                    "triggers": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Identified triggers or causes"
                    },
                    "associated_emotions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "emotion": {
                                    "type": "string",
                                    "description": "Associated emotion"
                                },
                                "intensity": {
                                    "type": "integer",
                                    "minimum": 1,
                                    "maximum": 10,
                                    "description": "Intensity of associated emotion"
                                }
                            }
                        }
                    }
                },
                "required": ["primary_emotion", "intensity"]
            },
            "support_provided": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["active_listening", "validation", "guidance", "resource_sharing", "crisis_intervention"],
                        "description": "Type of support provided"
                    },
                    "approach": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "enum": [
                                "empathetic_listening",
                                "cognitive_reframing",
                                "emotional_validation",
                                "problem_solving",
                                "mindfulness",
                                "stress_management"
                            ]
                        },
                        "description": "Approaches used in providing support"
                    },
                    "resources_shared": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "resource_type": {
                                    "type": "string",
                                    "enum": ["article", "video", "exercise", "contact", "service"],
                                    "description": "Type of resource"
                                },
                                "title": {
                                    "type": "string",
                                    "description": "Title or name of the resource"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Brief description of the resource"
                                },
                                "url": {
                                    "type": "string",
                                    "description": "URL if applicable"
                                }
                            },
                            "required": ["resource_type", "title"]
                        }
                    }
                },
                "required": ["type", "approach"]
            },
            "outcomes": {
                "type": "object",
                "properties": {
                    "emotional_change": {
                        "type": "object",
                        "properties": {
                            "direction": {
                                "type": "string",
                                "enum": ["improved", "unchanged", "deteriorated"],
                                "description": "Direction of emotional change"
                            },
                            "magnitude": {
                                "type": "integer",
                                "minimum": 0,
                                "maximum": 10,
                                "description": "Magnitude of change"
                            }
                        }
                    },
                    "insights_gained": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Insights or realizations gained during support"
                    },
                    "action_items": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "action": {
                                    "type": "string",
                                    "description": "Planned action"
                                },
                                "timeframe": {
                                    "type": "string",
                                    "description": "Timeframe for action"
                                },
                                "support_needed": {
                                    "type": "string",
                                    "description": "Additional support needed"
                                }
                            },
                            "required": ["action"]
                        }
                    }
                }
            },
            "follow_up": {
                "type": "object",
                "properties": {
                    "recommended": {
                        "type": "boolean",
                        "description": "Whether follow-up is recommended"
                    },
                    "type": {
                        "type": "string",
                        "enum": ["check_in", "session", "referral", "crisis_support"],
                        "description": "Type of follow-up"
                    },
                    "timeframe": {
                        "type": "string",
                        "description": "Recommended timeframe for follow-up"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes for follow-up"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "support_provider": {
                        "type": "string",
                        "description": "Identifier of support provider"
                    },
                    "session_duration": {
                        "type": "integer",
                        "description": "Duration of support session in minutes"
                    },
                    "platform": {
                        "type": "string",
                        "description": "Platform or medium used for support"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Relevant tags for the support session"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "support_id",
            "participant",
            "emotional_state",
            "support_provided"
        ]
    }
) 