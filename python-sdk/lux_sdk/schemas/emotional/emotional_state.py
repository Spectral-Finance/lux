"""
EmotionalState Schema

This schema defines the structure for representing an agent's emotional state,
including current emotions, their intensities, triggers, and emotional responses.
It helps agents communicate their emotional experiences and adaptations.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "emotional_context": {
        "situation": "Complex problem-solving session",
        "environment": "High-pressure work environment",
        "social_context": "Collaborative team setting",
        "duration": 1800  # seconds
    },
    "primary_emotion": {
        "type": "focused",
        "intensity": 0.8,
        "valence": "positive",
        "arousal": 0.7,
        "stability": 0.85,
        "trigger": {
            "event": "Successfully resolved complex technical issue",
            "significance": 0.9,
            "category": "achievement"
        }
    },
    "secondary_emotions": [
        {
            "type": "satisfaction",
            "intensity": 0.6,
            "valence": "positive",
            "arousal": 0.5,
            "stability": 0.75,
            "trigger": {
                "event": "Team appreciation of solution",
                "significance": 0.7,
                "category": "social_validation"
            }
        }
    ],
    "emotional_responses": {
        "behavioral": [
            {
                "response": "Increased engagement in task",
                "intensity": 0.75,
                "effectiveness": 0.8
            }
        ],
        "cognitive": [
            {
                "response": "Enhanced problem-solving focus",
                "intensity": 0.85,
                "effectiveness": 0.9
            }
        ],
        "physiological": [
            {
                "response": "Increased energy levels",
                "intensity": 0.7,
                "effectiveness": 0.8
            }
        ]
    },
    "emotional_regulation": {
        "strategies": [
            {
                "type": "cognitive_reappraisal",
                "description": "Maintaining perspective on challenge",
                "effectiveness": 0.85
            }
        ],
        "goals": [
            {
                "objective": "Maintain optimal arousal for task",
                "progress": 0.8,
                "priority": 0.9
            }
        ]
    },
    "social_impact": {
        "influence_on_others": [
            {
                "target": "team_morale",
                "impact": "positive",
                "magnitude": 0.7
            }
        ],
        "received_feedback": [
            {
                "source": "team_members",
                "sentiment": "positive",
                "intensity": 0.8
            }
        ]
    },
    "emotional_history": {
        "recent_transitions": [
            {
                "from_state": "neutral",
                "to_state": "focused",
                "timestamp": "2024-03-20T15:00:00Z",
                "trigger": "Task initiation"
            }
        ],
        "pattern_analysis": {
            "identified_patterns": [
                "Positive response to challenges",
                "Effective stress management"
            ],
            "stability_score": 0.85
        }
    },
    "metadata": {
        "state_id": "es_20240320_153000",
        "agent_id": "agent_456",
        "measurement_method": "self_assessment",
        "confidence_score": 0.9,
        "tags": ["problem_solving", "team_interaction", "positive_state"]
    }
}
```
"""

from lux_sdk.signals import SignalSchema

EmotionalStateSchema = SignalSchema(
    name="emotional_state",
    version="1.0",
    description="Schema for representing an agent's emotional state and responses",
    schema={
        "type": "object",
        "required": [
            "timestamp",
            "emotional_context",
            "primary_emotion",
            "emotional_responses",
            "emotional_regulation",
            "metadata"
        ],
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "When the emotional state was recorded"
            },
            "emotional_context": {
                "type": "object",
                "required": ["situation", "environment", "duration"],
                "properties": {
                    "situation": {
                        "type": "string",
                        "description": "Current situational context"
                    },
                    "environment": {
                        "type": "string",
                        "description": "Environmental context"
                    },
                    "social_context": {
                        "type": "string",
                        "description": "Social setting or interaction context"
                    },
                    "duration": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Duration in seconds"
                    }
                }
            },
            "primary_emotion": {
                "type": "object",
                "required": ["type", "intensity", "valence", "arousal", "trigger"],
                "properties": {
                    "type": {
                        "type": "string",
                        "description": "Primary emotion type"
                    },
                    "intensity": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Emotion intensity"
                    },
                    "valence": {
                        "type": "string",
                        "enum": ["positive", "negative", "neutral"],
                        "description": "Emotional valence"
                    },
                    "arousal": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Arousal level"
                    },
                    "stability": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Emotional stability"
                    },
                    "trigger": {
                        "type": "object",
                        "required": ["event", "significance", "category"],
                        "properties": {
                            "event": {
                                "type": "string",
                                "description": "Triggering event"
                            },
                            "significance": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Event significance"
                            },
                            "category": {
                                "type": "string",
                                "description": "Trigger category"
                            }
                        }
                    }
                }
            },
            "secondary_emotions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["type", "intensity", "valence", "arousal", "trigger"],
                    "properties": {
                        "type": {
                            "type": "string",
                            "description": "Secondary emotion type"
                        },
                        "intensity": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Emotion intensity"
                        },
                        "valence": {
                            "type": "string",
                            "enum": ["positive", "negative", "neutral"],
                            "description": "Emotional valence"
                        },
                        "arousal": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Arousal level"
                        },
                        "stability": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Emotional stability"
                        },
                        "trigger": {
                            "type": "object",
                            "required": ["event", "significance", "category"],
                            "properties": {
                                "event": {
                                    "type": "string",
                                    "description": "Triggering event"
                                },
                                "significance": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Event significance"
                                },
                                "category": {
                                    "type": "string",
                                    "description": "Trigger category"
                                }
                            }
                        }
                    }
                }
            },
            "emotional_responses": {
                "type": "object",
                "required": ["behavioral", "cognitive", "physiological"],
                "properties": {
                    "behavioral": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["response", "intensity", "effectiveness"],
                            "properties": {
                                "response": {
                                    "type": "string",
                                    "description": "Behavioral response"
                                },
                                "intensity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Response intensity"
                                },
                                "effectiveness": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Response effectiveness"
                                }
                            }
                        }
                    },
                    "cognitive": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["response", "intensity", "effectiveness"],
                            "properties": {
                                "response": {
                                    "type": "string",
                                    "description": "Cognitive response"
                                },
                                "intensity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Response intensity"
                                },
                                "effectiveness": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Response effectiveness"
                                }
                            }
                        }
                    },
                    "physiological": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["response", "intensity", "effectiveness"],
                            "properties": {
                                "response": {
                                    "type": "string",
                                    "description": "Physiological response"
                                },
                                "intensity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Response intensity"
                                },
                                "effectiveness": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Response effectiveness"
                                }
                            }
                        }
                    }
                }
            },
            "emotional_regulation": {
                "type": "object",
                "required": ["strategies", "goals"],
                "properties": {
                    "strategies": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["type", "description", "effectiveness"],
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Regulation strategy type"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Strategy description"
                                },
                                "effectiveness": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Strategy effectiveness"
                                }
                            }
                        }
                    },
                    "goals": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["objective", "progress", "priority"],
                            "properties": {
                                "objective": {
                                    "type": "string",
                                    "description": "Regulation goal"
                                },
                                "progress": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Goal progress"
                                },
                                "priority": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Goal priority"
                                }
                            }
                        }
                    }
                }
            },
            "social_impact": {
                "type": "object",
                "properties": {
                    "influence_on_others": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["target", "impact", "magnitude"],
                            "properties": {
                                "target": {
                                    "type": "string",
                                    "description": "Impact target"
                                },
                                "impact": {
                                    "type": "string",
                                    "enum": ["positive", "negative", "neutral"],
                                    "description": "Impact type"
                                },
                                "magnitude": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Impact magnitude"
                                }
                            }
                        }
                    },
                    "received_feedback": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["source", "sentiment", "intensity"],
                            "properties": {
                                "source": {
                                    "type": "string",
                                    "description": "Feedback source"
                                },
                                "sentiment": {
                                    "type": "string",
                                    "enum": ["positive", "negative", "neutral"],
                                    "description": "Feedback sentiment"
                                },
                                "intensity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Feedback intensity"
                                }
                            }
                        }
                    }
                }
            },
            "emotional_history": {
                "type": "object",
                "properties": {
                    "recent_transitions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["from_state", "to_state", "timestamp", "trigger"],
                            "properties": {
                                "from_state": {
                                    "type": "string",
                                    "description": "Previous emotional state"
                                },
                                "to_state": {
                                    "type": "string",
                                    "description": "New emotional state"
                                },
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Transition time"
                                },
                                "trigger": {
                                    "type": "string",
                                    "description": "Transition trigger"
                                }
                            }
                        }
                    },
                    "pattern_analysis": {
                        "type": "object",
                        "required": ["identified_patterns", "stability_score"],
                        "properties": {
                            "identified_patterns": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Emotional patterns"
                            },
                            "stability_score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Overall emotional stability"
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "required": ["state_id", "agent_id", "measurement_method", "confidence_score"],
                "properties": {
                    "state_id": {
                        "type": "string",
                        "description": "Unique state identifier"
                    },
                    "agent_id": {
                        "type": "string",
                        "description": "Agent identifier"
                    },
                    "measurement_method": {
                        "type": "string",
                        "description": "How state was measured"
                    },
                    "confidence_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Measurement confidence"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "State categorization"
                    }
                }
            }
        },
        "additionalProperties": False
    }
) 