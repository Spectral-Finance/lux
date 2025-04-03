"""
EmotionRecognition Schema

This schema defines the structure for representing emotion recognition and analysis.
It's particularly useful for:
- Detecting emotional states
- Analyzing emotional context
- Tracking emotional changes
- Multi-modal emotion recognition
- Emotional response planning

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.emotional.emotion_recognition import EmotionRecognitionSchema

# Create an emotion recognition analysis
signal = Signal(
    schema=EmotionRecognitionSchema,
    payload={
        "context": {
            "situation": "Customer support interaction",
            "timestamp": "2024-03-15T14:30:00Z",
            "channel": "chat",
            "duration_seconds": 300
        },
        "subject": {
            "type": "customer",
            "identifier": "anonymous_user_123",
            "interaction_history": {
                "total_interactions": 3,
                "last_interaction": "2024-03-10T09:15:00Z",
                "satisfaction_trend": "declining"
            }
        },
        "detected_emotions": [
            {
                "emotion": "frustration",
                "confidence": 0.85,
                "intensity": 0.7,
                "timestamp": "2024-03-15T14:32:00Z",
                "duration_seconds": 60,
                "indicators": [
                    {
                        "type": "text",
                        "signals": [
                            "repeated punctuation",
                            "uppercase emphasis",
                            "negative sentiment words"
                        ],
                        "confidence": 0.9
                    },
                    {
                        "type": "behavioral",
                        "signals": [
                            "rapid message frequency",
                            "message editing pattern"
                        ],
                        "confidence": 0.8
                    }
                ],
                "context_triggers": [
                    "repeated failed attempts",
                    "unclear documentation"
                ]
            },
            {
                "emotion": "relief",
                "confidence": 0.75,
                "intensity": 0.6,
                "timestamp": "2024-03-15T14:35:00Z",
                "duration_seconds": 30,
                "indicators": [
                    {
                        "type": "text",
                        "signals": [
                            "positive sentiment words",
                            "gratitude expressions"
                        ],
                        "confidence": 0.8
                    }
                ],
                "context_triggers": [
                    "problem resolution",
                    "clear explanation provided"
                ]
            }
        ],
        "emotional_progression": {
            "initial_state": {
                "dominant_emotion": "neutral",
                "intensity": 0.3
            },
            "transitions": [
                {
                    "from_emotion": "neutral",
                    "to_emotion": "frustration",
                    "trigger": "technical difficulty",
                    "timestamp": "2024-03-15T14:32:00Z"
                },
                {
                    "from_emotion": "frustration",
                    "to_emotion": "relief",
                    "trigger": "issue resolution",
                    "timestamp": "2024-03-15T14:35:00Z"
                }
            ],
            "final_state": {
                "dominant_emotion": "relief",
                "intensity": 0.6
            }
        },
        "analysis": {
            "overall_sentiment": "mixed",
            "key_moments": [
                {
                    "timestamp": "2024-03-15T14:32:00Z",
                    "description": "Peak frustration during technical difficulty",
                    "significance": 0.8
                },
                {
                    "timestamp": "2024-03-15T14:35:00Z",
                    "description": "Positive transition after resolution",
                    "significance": 0.7
                }
            ],
            "patterns": [
                {
                    "pattern": "frustration-relief cycle",
                    "frequency": "common",
                    "context": "technical support interactions"
                }
            ]
        },
        "recommendations": [
            {
                "action": "Improve error documentation",
                "priority": 0.8,
                "rationale": "Reduce initial frustration period",
                "expected_impact": "Shorter resolution time"
            },
            {
                "action": "Implement proactive support triggers",
                "priority": 0.7,
                "rationale": "Intervene before peak frustration",
                "expected_impact": "Better emotional progression"
            }
        ],
        "confidence_metrics": {
            "overall_confidence": 0.82,
            "data_quality": 0.9,
            "context_reliability": 0.85
        }
    }
)
```

Schema Structure:
- context: Situation and environment details
- subject: Information about the individual
- detected_emotions: Array of recognized emotions
- emotional_progression: Emotional state changes
- analysis: Patterns and key moments
- recommendations: Suggested actions
- confidence_metrics: Reliability measures

The schema enforces:
- Valid emotion categories
- Confidence and intensity ranges
- Temporal consistency
- Required emotional indicators
"""

from lux_sdk.signals import SignalSchema

SCHEMA = {
    "type": "object",
    "properties": {
        "context": {
            "type": "object",
            "properties": {
                "situation": {
                    "type": "string",
                    "description": "Description of the context"
                },
                "timestamp": {
                    "type": "string",
                    "format": "date-time",
                    "description": "When the analysis occurred"
                },
                "channel": {
                    "type": "string",
                    "description": "Communication channel"
                },
                "duration_seconds": {
                    "type": "number",
                    "minimum": 0,
                    "description": "Duration of the interaction"
                }
            },
            "required": ["situation", "timestamp"],
            "additionalProperties": False
        },
        "subject": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "description": "Type of subject"
                },
                "identifier": {
                    "type": "string",
                    "description": "Subject identifier"
                },
                "interaction_history": {
                    "type": "object",
                    "properties": {
                        "total_interactions": {
                            "type": "integer",
                            "minimum": 0,
                            "description": "Number of past interactions"
                        },
                        "last_interaction": {
                            "type": "string",
                            "format": "date-time",
                            "description": "Timestamp of last interaction"
                        },
                        "satisfaction_trend": {
                            "type": "string",
                            "description": "Trend in satisfaction"
                        }
                    },
                    "additionalProperties": False
                }
            },
            "required": ["type"],
            "additionalProperties": False
        },
        "detected_emotions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "emotion": {
                        "type": "string",
                        "description": "Identified emotion"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in detection"
                    },
                    "intensity": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Intensity of the emotion"
                    },
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the emotion was detected"
                    },
                    "duration_seconds": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Duration of the emotional state"
                    },
                    "indicators": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["text", "voice", "facial", "behavioral", "physiological"],
                                    "description": "Type of indicator"
                                },
                                "signals": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Specific signals observed"
                                },
                                "confidence": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Confidence in this indicator"
                                }
                            },
                            "required": ["type", "signals"],
                            "additionalProperties": False
                        }
                    },
                    "context_triggers": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Events or factors triggering the emotion"
                    }
                },
                "required": ["emotion", "confidence", "intensity"],
                "additionalProperties": False
            },
            "minItems": 1,
            "description": "Array of detected emotions"
        },
        "emotional_progression": {
            "type": "object",
            "properties": {
                "initial_state": {
                    "type": "object",
                    "properties": {
                        "dominant_emotion": {
                            "type": "string",
                            "description": "Initial emotional state"
                        },
                        "intensity": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Initial intensity"
                        }
                    },
                    "required": ["dominant_emotion", "intensity"],
                    "additionalProperties": False
                },
                "transitions": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "from_emotion": {
                                "type": "string",
                                "description": "Starting emotion"
                            },
                            "to_emotion": {
                                "type": "string",
                                "description": "Ending emotion"
                            },
                            "trigger": {
                                "type": "string",
                                "description": "Cause of transition"
                            },
                            "timestamp": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When the transition occurred"
                            }
                        },
                        "required": ["from_emotion", "to_emotion", "timestamp"],
                        "additionalProperties": False
                    }
                },
                "final_state": {
                    "type": "object",
                    "properties": {
                        "dominant_emotion": {
                            "type": "string",
                            "description": "Final emotional state"
                        },
                        "intensity": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Final intensity"
                        }
                    },
                    "required": ["dominant_emotion", "intensity"],
                    "additionalProperties": False
                }
            },
            "required": ["initial_state", "final_state"],
            "additionalProperties": False
        },
        "analysis": {
            "type": "object",
            "properties": {
                "overall_sentiment": {
                    "type": "string",
                    "description": "General emotional tone"
                },
                "key_moments": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "timestamp": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When the moment occurred"
                            },
                            "description": {
                                "type": "string",
                                "description": "Description of the moment"
                            },
                            "significance": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Importance of the moment"
                            }
                        },
                        "required": ["timestamp", "description"],
                        "additionalProperties": False
                    }
                },
                "patterns": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "pattern": {
                                "type": "string",
                                "description": "Identified pattern"
                            },
                            "frequency": {
                                "type": "string",
                                "description": "How often the pattern occurs"
                            },
                            "context": {
                                "type": "string",
                                "description": "When/where the pattern appears"
                            }
                        },
                        "required": ["pattern"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["overall_sentiment"],
            "additionalProperties": False
        },
        "recommendations": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "description": "Recommended action"
                    },
                    "priority": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Priority of the recommendation"
                    },
                    "rationale": {
                        "type": "string",
                        "description": "Reasoning for the recommendation"
                    },
                    "expected_impact": {
                        "type": "string",
                        "description": "Anticipated outcome"
                    }
                },
                "required": ["action", "priority", "rationale"],
                "additionalProperties": False
            }
        },
        "confidence_metrics": {
            "type": "object",
            "properties": {
                "overall_confidence": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Overall confidence in analysis"
                },
                "data_quality": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Quality of input data"
                },
                "context_reliability": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Reliability of context information"
                }
            },
            "required": ["overall_confidence"],
            "additionalProperties": False
        }
    },
    "required": [
        "context",
        "detected_emotions",
        "emotional_progression",
        "analysis",
        "confidence_metrics"
    ],
    "additionalProperties": False
}

EmotionRecognitionSchema = SignalSchema(
    name="lux.emotional.emotion_recognition",
    version="1.0",
    description="Schema for emotion recognition and analysis",
    schema=SCHEMA
) 