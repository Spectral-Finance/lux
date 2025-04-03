"""
EmpathyResponse Schema

This schema defines the structure for representing empathetic responses and interactions.
It's particularly useful for:
- Empathetic communication
- Emotional support
- Understanding and validation
- Appropriate response generation
- Building emotional rapport

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.emotional.empathy_response import EmpathyResponseSchema

# Create an empathy response
signal = Signal(
    schema=EmpathyResponseSchema,
    payload={
        "context": {
            "situation": "User expressing frustration with software issues",
            "timestamp": "2024-03-15T14:30:00Z",
            "channel": "support_chat",
            "urgency_level": 0.8
        },
        "emotional_understanding": {
            "perceived_emotions": [
                {
                    "emotion": "frustration",
                    "intensity": 0.7,
                    "confidence": 0.85,
                    "source_signals": [
                        "Repeated issue reporting",
                        "Strong negative language",
                        "Expression of time pressure"
                    ]
                },
                {
                    "emotion": "anxiety",
                    "intensity": 0.5,
                    "confidence": 0.75,
                    "source_signals": [
                        "Concern about deadline impact",
                        "Frequent status requests"
                    ]
                }
            ],
            "emotional_context": {
                "background": "Critical project deadline approaching",
                "impact_areas": ["work productivity", "project timeline"],
                "stakeholders": ["user", "project team", "client"]
            }
        },
        "empathy_elements": {
            "acknowledgment": {
                "content": "I understand how frustrating these technical issues must be, especially with your project deadline approaching",
                "type": "emotional_validation",
                "strength": 0.8
            },
            "perspective_taking": {
                "understanding": "The combination of technical problems and time pressure is particularly stressful",
                "insights": [
                    "User's professional reputation at stake",
                    "Cascading impact on team productivity"
                ]
            },
            "support_approach": {
                "primary_focus": "resolution_with_emotional_support",
                "key_aspects": [
                    "Acknowledge time sensitivity",
                    "Provide clear progress updates",
                    "Offer temporary workarounds"
                ]
            }
        },
        "response_components": {
            "validation": {
                "message": "Your frustration is completely understandable in this situation",
                "empathy_level": 0.9,
                "focus_points": ["time pressure", "work impact"]
            },
            "understanding": {
                "message": "I can see how this is affecting your project timeline",
                "empathy_level": 0.85,
                "focus_points": ["deadline concern", "professional impact"]
            },
            "action_plan": {
                "immediate_steps": [
                    {
                        "action": "Prioritize issue investigation",
                        "timeframe": "immediate",
                        "reassurance": "I'll look into this right away"
                    },
                    {
                        "action": "Provide workaround options",
                        "timeframe": "next 15 minutes",
                        "reassurance": "I'll help you find a temporary solution"
                    }
                ],
                "follow_up": {
                    "timing": "every 10 minutes",
                    "focus": "progress updates and emotional check-in"
                }
            }
        },
        "communication_strategy": {
            "tone": "supportive_professional",
            "key_phrases": [
                {
                    "text": "I'm here to help you through this",
                    "purpose": "establishing support",
                    "timing": "immediate"
                },
                {
                    "text": "Let's tackle this together",
                    "purpose": "building collaboration",
                    "timing": "after validation"
                }
            ],
            "pacing": {
                "response_speed": "prompt",
                "update_frequency": "high",
                "explanation_detail": "balanced"
            }
        },
        "effectiveness_metrics": {
            "emotional_resonance": 0.85,
            "practical_support": 0.9,
            "response_timeliness": 0.95,
            "user_reception": {
                "initial_response": "positive",
                "stress_reduction": 0.3,
                "confidence_building": 0.7
            }
        }
    }
)
```

Schema Structure:
- context: Situation and interaction details
- emotional_understanding: Recognition of emotions and context
- empathy_elements: Core components of empathetic response
- response_components: Structured response elements
- communication_strategy: Approach to empathetic communication
- effectiveness_metrics: Impact and reception measures

The schema enforces:
- Valid emotion categories
- Appropriate empathy levels
- Required response components
- Communication strategy elements
- Effectiveness measurements
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
                    "description": "Description of the current situation"
                },
                "timestamp": {
                    "type": "string",
                    "format": "date-time",
                    "description": "When the interaction occurred"
                },
                "channel": {
                    "type": "string",
                    "description": "Communication channel"
                },
                "urgency_level": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Urgency of the situation"
                }
            },
            "required": ["situation", "timestamp"],
            "additionalProperties": False
        },
        "emotional_understanding": {
            "type": "object",
            "properties": {
                "perceived_emotions": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "emotion": {
                                "type": "string",
                                "description": "Identified emotion"
                            },
                            "intensity": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Intensity of the emotion"
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Confidence in emotion identification"
                            },
                            "source_signals": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Signals indicating the emotion"
                            }
                        },
                        "required": ["emotion", "intensity", "confidence"],
                        "additionalProperties": False
                    }
                },
                "emotional_context": {
                    "type": "object",
                    "properties": {
                        "background": {
                            "type": "string",
                            "description": "Relevant background information"
                        },
                        "impact_areas": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Areas affected by the situation"
                        },
                        "stakeholders": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "People affected or involved"
                        }
                    },
                    "required": ["background"],
                    "additionalProperties": False
                }
            },
            "required": ["perceived_emotions"],
            "additionalProperties": False
        },
        "empathy_elements": {
            "type": "object",
            "properties": {
                "acknowledgment": {
                    "type": "object",
                    "properties": {
                        "content": {
                            "type": "string",
                            "description": "Acknowledgment message"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["emotional_validation", "situation_recognition", "impact_acknowledgment"],
                            "description": "Type of acknowledgment"
                        },
                        "strength": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Strength of acknowledgment"
                        }
                    },
                    "required": ["content", "type"],
                    "additionalProperties": False
                },
                "perspective_taking": {
                    "type": "object",
                    "properties": {
                        "understanding": {
                            "type": "string",
                            "description": "Demonstrated understanding"
                        },
                        "insights": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Key insights from perspective"
                        }
                    },
                    "required": ["understanding"],
                    "additionalProperties": False
                },
                "support_approach": {
                    "type": "object",
                    "properties": {
                        "primary_focus": {
                            "type": "string",
                            "description": "Main approach to support"
                        },
                        "key_aspects": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Important aspects of support"
                        }
                    },
                    "required": ["primary_focus"],
                    "additionalProperties": False
                }
            },
            "required": ["acknowledgment", "perspective_taking"],
            "additionalProperties": False
        },
        "response_components": {
            "type": "object",
            "properties": {
                "validation": {
                    "type": "object",
                    "properties": {
                        "message": {
                            "type": "string",
                            "description": "Validation message"
                        },
                        "empathy_level": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Level of empathy expressed"
                        },
                        "focus_points": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Key points of validation"
                        }
                    },
                    "required": ["message", "empathy_level"],
                    "additionalProperties": False
                },
                "understanding": {
                    "type": "object",
                    "properties": {
                        "message": {
                            "type": "string",
                            "description": "Understanding message"
                        },
                        "empathy_level": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Level of empathy shown"
                        },
                        "focus_points": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Key points of understanding"
                        }
                    },
                    "required": ["message", "empathy_level"],
                    "additionalProperties": False
                },
                "action_plan": {
                    "type": "object",
                    "properties": {
                        "immediate_steps": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "action": {
                                        "type": "string",
                                        "description": "Action to take"
                                    },
                                    "timeframe": {
                                        "type": "string",
                                        "description": "When to take action"
                                    },
                                    "reassurance": {
                                        "type": "string",
                                        "description": "Reassuring message"
                                    }
                                },
                                "required": ["action", "timeframe"],
                                "additionalProperties": False
                            }
                        },
                        "follow_up": {
                            "type": "object",
                            "properties": {
                                "timing": {
                                    "type": "string",
                                    "description": "Follow-up timing"
                                },
                                "focus": {
                                    "type": "string",
                                    "description": "Focus of follow-up"
                                }
                            },
                            "required": ["timing"],
                            "additionalProperties": False
                        }
                    },
                    "required": ["immediate_steps"],
                    "additionalProperties": False
                }
            },
            "required": ["validation", "understanding"],
            "additionalProperties": False
        },
        "communication_strategy": {
            "type": "object",
            "properties": {
                "tone": {
                    "type": "string",
                    "description": "Communication tone"
                },
                "key_phrases": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "text": {
                                "type": "string",
                                "description": "Phrase to use"
                            },
                            "purpose": {
                                "type": "string",
                                "description": "Purpose of the phrase"
                            },
                            "timing": {
                                "type": "string",
                                "description": "When to use the phrase"
                            }
                        },
                        "required": ["text", "purpose"],
                        "additionalProperties": False
                    }
                },
                "pacing": {
                    "type": "object",
                    "properties": {
                        "response_speed": {
                            "type": "string",
                            "description": "Speed of responses"
                        },
                        "update_frequency": {
                            "type": "string",
                            "description": "Frequency of updates"
                        },
                        "explanation_detail": {
                            "type": "string",
                            "description": "Level of detail in explanations"
                        }
                    },
                    "additionalProperties": False
                }
            },
            "required": ["tone"],
            "additionalProperties": False
        },
        "effectiveness_metrics": {
            "type": "object",
            "properties": {
                "emotional_resonance": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "How well emotions were addressed"
                },
                "practical_support": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Effectiveness of practical help"
                },
                "response_timeliness": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Timeliness of response"
                },
                "user_reception": {
                    "type": "object",
                    "properties": {
                        "initial_response": {
                            "type": "string",
                            "description": "Initial user reaction"
                        },
                        "stress_reduction": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Amount of stress reduced"
                        },
                        "confidence_building": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Increase in user confidence"
                        }
                    },
                    "required": ["initial_response"],
                    "additionalProperties": False
                }
            },
            "required": ["emotional_resonance", "practical_support"],
            "additionalProperties": False
        }
    },
    "required": [
        "context",
        "emotional_understanding",
        "empathy_elements",
        "response_components",
        "communication_strategy",
        "effectiveness_metrics"
    ],
    "additionalProperties": False
}

EmpathyResponseSchema = SignalSchema(
    name="lux.emotional.empathy_response",
    version="1.0",
    description="Schema for representing empathetic responses and interactions",
    schema=SCHEMA
) 