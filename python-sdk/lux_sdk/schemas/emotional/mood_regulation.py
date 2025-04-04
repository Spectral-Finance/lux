"""
Schema for tracking mood regulation strategies and outcomes.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class MoodRegulationSchema(SignalSchema):
    """Schema for tracking and analyzing mood regulation strategies and their effectiveness.
    
    This schema captures the process and outcomes of mood regulation attempts, including
    initial emotional states, regulation strategies, interventions, and results.
    
    Example:
        {
            "timestamp": "2024-04-03T14:32:10Z",
            "regulation_id": "reg-123",
            "subject_id": "subj-456",
            "initial_state": {
                "mood": "anxious",
                "intensity": 7,
                "triggers": ["work deadline", "public speaking"],
                "physical_symptoms": ["rapid heartbeat", "sweating"]
            },
            "regulation_strategy": {
                "technique": "deep breathing",
                "category": "relaxation",
                "duration": 15,
                "difficulty_level": "moderate"
            },
            "interventions": [
                {
                    "intervention_type": "breathing exercise",
                    "description": "4-7-8 breathing pattern",
                    "timing": "immediate",
                    "effectiveness": 8
                }
            ],
            "outcome": {
                "final_mood": "calm",
                "intensity_change": -4,
                "success_rating": 8,
                "duration_of_effect": 120
            },
            "learning_points": [
                {
                    "observation": "Breathing technique most effective when applied early",
                    "applicability": "High stress situations",
                    "future_adjustments": "Start regulation earlier when noticing triggers"
                }
            ],
            "contextual_factors": {
                "location": "office",
                "social_context": "alone",
                "time_of_day": "morning",
                "external_factors": ["quiet environment", "private space"]
            },
            "metadata": {
                "created_at": "2024-04-03T14:32:10Z",
                "updated_at": "2024-04-03T14:32:10Z",
                "recorder": "self",
                "version": "1.0",
                "tags": ["anxiety", "work-related", "breathing"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="mood_regulation",
            version="1.0",
            description="Schema for tracking and analyzing mood regulation strategies and their effectiveness",
            schema={
                "type": "object",
                "required": ["timestamp", "regulation_id", "subject_id", "initial_state", "regulation_strategy", "interventions", "outcome"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the mood regulation record"
                    },
                    "regulation_id": {
                        "type": "string",
                        "description": "Unique identifier for the mood regulation record"
                    },
                    "subject_id": {
                        "type": "string",
                        "description": "Identifier of the subject"
                    },
                    "initial_state": {
                        "type": "object",
                        "required": ["mood", "intensity"],
                        "properties": {
                            "mood": {
                                "type": "string",
                                "description": "Primary mood state"
                            },
                            "intensity": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 10,
                                "description": "Intensity level of the mood (0-10)"
                            },
                            "triggers": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Factors triggering the mood"
                            },
                            "physical_symptoms": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Associated physical symptoms"
                            }
                        }
                    },
                    "regulation_strategy": {
                        "type": "object",
                        "required": ["technique", "category"],
                        "properties": {
                            "technique": {
                                "type": "string",
                                "description": "Name of the regulation technique"
                            },
                            "category": {
                                "type": "string",
                                "enum": ["relaxation", "cognitive", "behavioral", "social", "physical"],
                                "description": "Category of regulation strategy"
                            },
                            "duration": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Duration of strategy application in minutes"
                            },
                            "difficulty_level": {
                                "type": "string",
                                "enum": ["easy", "moderate", "difficult"],
                                "description": "Perceived difficulty of implementation"
                            }
                        }
                    },
                    "interventions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["intervention_type", "effectiveness"],
                            "properties": {
                                "intervention_type": {
                                    "type": "string",
                                    "description": "Type of intervention"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the intervention"
                                },
                                "timing": {
                                    "type": "string",
                                    "description": "When the intervention was applied"
                                },
                                "effectiveness": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 10,
                                    "description": "Effectiveness rating (0-10)"
                                }
                            }
                        }
                    },
                    "outcome": {
                        "type": "object",
                        "required": ["final_mood", "success_rating"],
                        "properties": {
                            "final_mood": {
                                "type": "string",
                                "description": "Resulting mood state"
                            },
                            "intensity_change": {
                                "type": "number",
                                "description": "Change in intensity level"
                            },
                            "success_rating": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 10,
                                "description": "Overall success rating (0-10)"
                            },
                            "duration_of_effect": {
                                "type": "number",
                                "minimum": 0,
                                "description": "How long the effect lasted in minutes"
                            }
                        }
                    },
                    "learning_points": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["observation"],
                            "properties": {
                                "observation": {
                                    "type": "string",
                                    "description": "Key observation or insight"
                                },
                                "applicability": {
                                    "type": "string",
                                    "description": "Contexts where this learning applies"
                                },
                                "future_adjustments": {
                                    "type": "string",
                                    "description": "Suggested adjustments for future"
                                }
                            }
                        }
                    },
                    "contextual_factors": {
                        "type": "object",
                        "properties": {
                            "location": {
                                "type": "string",
                                "description": "Physical location"
                            },
                            "social_context": {
                                "type": "string",
                                "description": "Social environment"
                            },
                            "time_of_day": {
                                "type": "string",
                                "description": "Time when regulation occurred"
                            },
                            "external_factors": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Relevant external factors"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "updated_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "recorder": {
                                "type": "string",
                                "description": "Person or system recording the data"
                            },
                            "version": {
                                "type": "string",
                                "description": "Version of the assessment"
                            },
                            "tags": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Relevant tags"
                            }
                        }
                    }
                }
            }
        ) 