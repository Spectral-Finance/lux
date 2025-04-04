"""
EmotionalRegulation Schema

This schema defines the structure for representing emotional regulation processes and strategies.
It's particularly useful for:
- Emotion management
- Stress response modulation
- Adaptive coping strategies
- Emotional balance maintenance
- Self-regulation feedback

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.emotional.emotional_regulation import EmotionalRegulationSchema

# Create an emotional regulation process
signal = Signal(
    schema=EmotionalRegulationSchema,
    payload={
        "context": {
            "situation": "High-pressure project deadline",
            "timestamp": "2024-03-15T14:30:00Z",
            "environment": "remote_work",
            "duration_minutes": 120,
            "intensity_level": 0.8
        },
        "emotional_state": {
            "primary_emotion": {
                "type": "stress",
                "intensity": 0.75,
                "triggers": [
                    "approaching deadline",
                    "technical complications",
                    "team coordination challenges"
                ],
                "physical_indicators": [
                    "increased heart rate",
                    "muscle tension",
                    "shallow breathing"
                ]
            },
            "secondary_emotions": [
                {
                    "type": "anxiety",
                    "intensity": 0.6,
                    "triggers": ["uncertainty about outcome"]
                },
                {
                    "type": "frustration",
                    "intensity": 0.5,
                    "triggers": ["communication delays"]
                }
            ],
            "cognitive_patterns": [
                {
                    "pattern": "catastrophizing",
                    "frequency": "moderate",
                    "impact": 0.7,
                    "examples": [
                        "Project will fail completely",
                        "Team will lose confidence"
                    ]
                }
            ]
        },
        "regulation_strategies": {
            "immediate_interventions": [
                {
                    "technique": "deep_breathing",
                    "duration_minutes": 5,
                    "expected_impact": 0.6,
                    "implementation": {
                        "steps": [
                            "Find quiet space",
                            "4-7-8 breathing pattern",
                            "Focus on breath"
                        ],
                        "frequency": "every 30 minutes"
                    }
                },
                {
                    "technique": "cognitive_reframing",
                    "duration_minutes": 10,
                    "expected_impact": 0.7,
                    "implementation": {
                        "steps": [
                            "Identify negative thoughts",
                            "Challenge assumptions",
                            "Generate alternative perspectives"
                        ],
                        "focus_areas": [
                            "deadline pressure",
                            "team capabilities"
                        ]
                    }
                }
            ],
            "preventive_measures": [
                {
                    "strategy": "workload_management",
                    "description": "Break tasks into smaller chunks",
                    "implementation_plan": {
                        "timeframe": "daily",
                        "key_actions": [
                            "Priority assessment",
                            "Task decomposition",
                            "Progress tracking"
                        ]
                    }
                },
                {
                    "strategy": "communication_improvement",
                    "description": "Establish clear update protocols",
                    "implementation_plan": {
                        "timeframe": "ongoing",
                        "key_actions": [
                            "Regular check-ins",
                            "Status documentation",
                            "Feedback loops"
                        ]
                    }
                }
            ],
            "long_term_development": {
                "focus_areas": [
                    "stress resilience",
                    "time management",
                    "communication skills"
                ],
                "practices": [
                    {
                        "name": "mindfulness_training",
                        "frequency": "daily",
                        "duration_minutes": 15
                    },
                    {
                        "name": "stress_management_workshop",
                        "frequency": "monthly",
                        "duration_minutes": 60
                    }
                ]
            }
        },
        "progress_tracking": {
            "baseline_metrics": {
                "stress_level": 0.8,
                "coping_efficacy": 0.5,
                "emotional_awareness": 0.7
            },
            "intervention_outcomes": [
                {
                    "timestamp": "2024-03-15T14:45:00Z",
                    "strategy_used": "deep_breathing",
                    "effectiveness": 0.6,
                    "notes": "Reduced immediate tension"
                },
                {
                    "timestamp": "2024-03-15T15:00:00Z",
                    "strategy_used": "cognitive_reframing",
                    "effectiveness": 0.7,
                    "notes": "Improved perspective on deadline"
                }
            ],
            "overall_progress": {
                "stress_reduction": 0.3,
                "coping_improvement": 0.4,
                "resilience_building": 0.5
            }
        },
        "adaptation_recommendations": {
            "immediate_adjustments": [
                {
                    "focus": "breathing_technique",
                    "modification": "Increase frequency",
                    "rationale": "Shows good effectiveness"
                },
                {
                    "focus": "cognitive_exercises",
                    "modification": "Add team perspective",
                    "rationale": "Address collaboration stress"
                }
            ],
            "long_term_suggestions": [
                {
                    "area": "workload_management",
                    "suggestion": "Implement structured planning sessions",
                    "expected_benefit": "Better stress prevention"
                },
                {
                    "area": "skill_development",
                    "suggestion": "Regular stress management training",
                    "expected_benefit": "Improved resilience"
                }
            ]
        },
        "effectiveness_metrics": {
            "regulation_success": 0.7,
            "strategy_adherence": 0.8,
            "adaptation_speed": 0.6,
            "sustainability": 0.75,
            "detailed_outcomes": {
                "emotional_stability": 0.7,
                "cognitive_clarity": 0.8,
                "behavioral_control": 0.75
            }
        }
    }
)
```

Schema Structure:
- context: Situation and environmental factors
- emotional_state: Current emotional condition
- regulation_strategies: Approaches for emotional management
- progress_tracking: Monitoring of regulation efforts
- adaptation_recommendations: Suggested adjustments
- effectiveness_metrics: Success measures

The schema enforces:
- Valid emotion types and intensities
- Strategy implementation details
- Progress tracking requirements
- Effectiveness measurements
- Adaptation guidelines
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
                    "description": "Description of the situation"
                },
                "timestamp": {
                    "type": "string",
                    "format": "date-time",
                    "description": "When regulation began"
                },
                "environment": {
                    "type": "string",
                    "description": "Context environment"
                },
                "duration_minutes": {
                    "type": "number",
                    "minimum": 0,
                    "description": "Duration of the situation"
                },
                "intensity_level": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Situation intensity"
                }
            },
            "required": ["situation", "timestamp"],
            "additionalProperties": False
        },
        "emotional_state": {
            "type": "object",
            "properties": {
                "primary_emotion": {
                    "type": "object",
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
                        "triggers": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "What triggered the emotion"
                        },
                        "physical_indicators": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Physical manifestations"
                        }
                    },
                    "required": ["type", "intensity"],
                    "additionalProperties": False
                },
                "secondary_emotions": {
                    "type": "array",
                    "items": {
                        "type": "object",
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
                            "triggers": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "What triggered the emotion"
                            }
                        },
                        "required": ["type", "intensity"],
                        "additionalProperties": False
                    }
                },
                "cognitive_patterns": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "pattern": {
                                "type": "string",
                                "description": "Thought pattern"
                            },
                            "frequency": {
                                "type": "string",
                                "description": "How often it occurs"
                            },
                            "impact": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Pattern impact"
                            },
                            "examples": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Example thoughts"
                            }
                        },
                        "required": ["pattern", "impact"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["primary_emotion"],
            "additionalProperties": False
        },
        "regulation_strategies": {
            "type": "object",
            "properties": {
                "immediate_interventions": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "technique": {
                                "type": "string",
                                "description": "Intervention technique"
                            },
                            "duration_minutes": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Duration of intervention"
                            },
                            "expected_impact": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Expected effectiveness"
                            },
                            "implementation": {
                                "type": "object",
                                "properties": {
                                    "steps": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Implementation steps"
                                    },
                                    "frequency": {
                                        "type": "string",
                                        "description": "How often to apply"
                                    }
                                },
                                "required": ["steps"],
                                "additionalProperties": False
                            }
                        },
                        "required": ["technique", "expected_impact"],
                        "additionalProperties": False
                    }
                },
                "preventive_measures": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "strategy": {
                                "type": "string",
                                "description": "Prevention strategy"
                            },
                            "description": {
                                "type": "string",
                                "description": "Strategy description"
                            },
                            "implementation_plan": {
                                "type": "object",
                                "properties": {
                                    "timeframe": {
                                        "type": "string",
                                        "description": "Implementation timing"
                                    },
                                    "key_actions": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Key actions to take"
                                    }
                                },
                                "required": ["timeframe", "key_actions"],
                                "additionalProperties": False
                            }
                        },
                        "required": ["strategy", "description"],
                        "additionalProperties": False
                    }
                },
                "long_term_development": {
                    "type": "object",
                    "properties": {
                        "focus_areas": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Areas for development"
                        },
                        "practices": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {
                                        "type": "string",
                                        "description": "Practice name"
                                    },
                                    "frequency": {
                                        "type": "string",
                                        "description": "How often to practice"
                                    },
                                    "duration_minutes": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Practice duration"
                                    }
                                },
                                "required": ["name", "frequency"],
                                "additionalProperties": False
                            }
                        }
                    },
                    "required": ["focus_areas"],
                    "additionalProperties": False
                }
            },
            "required": ["immediate_interventions"],
            "additionalProperties": False
        },
        "progress_tracking": {
            "type": "object",
            "properties": {
                "baseline_metrics": {
                    "type": "object",
                    "properties": {
                        "stress_level": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Initial stress level"
                        },
                        "coping_efficacy": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Initial coping ability"
                        },
                        "emotional_awareness": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Initial awareness level"
                        }
                    },
                    "additionalProperties": False
                },
                "intervention_outcomes": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "timestamp": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When intervention occurred"
                            },
                            "strategy_used": {
                                "type": "string",
                                "description": "Strategy applied"
                            },
                            "effectiveness": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "How effective it was"
                            },
                            "notes": {
                                "type": "string",
                                "description": "Additional observations"
                            }
                        },
                        "required": ["timestamp", "strategy_used", "effectiveness"],
                        "additionalProperties": False
                    }
                },
                "overall_progress": {
                    "type": "object",
                    "properties": {
                        "stress_reduction": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Stress reduction achieved"
                        },
                        "coping_improvement": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Improvement in coping"
                        },
                        "resilience_building": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Resilience development"
                        }
                    },
                    "additionalProperties": False
                }
            },
            "required": ["intervention_outcomes"],
            "additionalProperties": False
        },
        "adaptation_recommendations": {
            "type": "object",
            "properties": {
                "immediate_adjustments": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "focus": {
                                "type": "string",
                                "description": "Adjustment focus"
                            },
                            "modification": {
                                "type": "string",
                                "description": "What to change"
                            },
                            "rationale": {
                                "type": "string",
                                "description": "Why make the change"
                            }
                        },
                        "required": ["focus", "modification"],
                        "additionalProperties": False
                    }
                },
                "long_term_suggestions": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "area": {
                                "type": "string",
                                "description": "Area for improvement"
                            },
                            "suggestion": {
                                "type": "string",
                                "description": "Suggested change"
                            },
                            "expected_benefit": {
                                "type": "string",
                                "description": "Anticipated outcome"
                            }
                        },
                        "required": ["area", "suggestion"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["immediate_adjustments"],
            "additionalProperties": False
        },
        "effectiveness_metrics": {
            "type": "object",
            "properties": {
                "regulation_success": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Overall success rate"
                },
                "strategy_adherence": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "How well strategies were followed"
                },
                "adaptation_speed": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "How quickly adapted"
                },
                "sustainability": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Long-term viability"
                },
                "detailed_outcomes": {
                    "type": "object",
                    "properties": {
                        "emotional_stability": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Stability improvement"
                        },
                        "cognitive_clarity": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Mental clarity"
                        },
                        "behavioral_control": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Behavior management"
                        }
                    },
                    "additionalProperties": False
                }
            },
            "required": ["regulation_success", "strategy_adherence"],
            "additionalProperties": False
        }
    },
    "required": [
        "context",
        "emotional_state",
        "regulation_strategies",
        "progress_tracking",
        "effectiveness_metrics"
    ],
    "additionalProperties": False
}

EmotionalRegulationSchema = SignalSchema(
    name="lux.emotional.emotional_regulation",
    version="1.0",
    description="Schema for emotional regulation processes and strategies",
    schema=SCHEMA
) 