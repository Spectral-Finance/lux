"""
Schema for representing social awareness and interpersonal understanding.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class SocialAwarenessSchema(SignalSchema):
    """Schema for representing social awareness, emotional intelligence, and interpersonal dynamics.
    
    This schema captures observations and analysis of social contexts, including emotional states,
    interpersonal dynamics, group behavior, and recommendations for improved social interaction.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "assessment_id": "sa-789",
            "context_id": "ctx-456",
            "social_context": {
                "setting": "team meeting",
                "participants": [
                    {
                        "participant_id": "p-123",
                        "role": "team lead",
                        "relationship_dynamics": ["authoritative with juniors", "collaborative with peers"]
                    }
                ],
                "cultural_factors": ["diverse team", "remote work culture"],
                "social_norms": ["professional communication", "respect for hierarchy"]
            },
            "emotional_observations": [
                {
                    "subject_id": "p-123",
                    "emotional_state": "confident",
                    "intensity": 0.8,
                    "behavioral_indicators": ["strong posture", "clear speech"],
                    "context_triggers": ["presenting project results"]
                }
            ],
            "interpersonal_dynamics": [
                {
                    "dynamic_id": "d-234",
                    "participants": ["p-123", "p-456"],
                    "interaction_pattern": "collaborative",
                    "power_dynamics": "balanced",
                    "communication_style": "direct",
                    "tension_points": ["differing project priorities"]
                }
            ],
            "group_dynamics": {
                "cohesion_level": 0.7,
                "power_structure": "hierarchical",
                "communication_patterns": ["open discussion", "active listening"],
                "group_mood": "engaged",
                "subgroup_formations": [
                    {
                        "members": ["p-123", "p-456"],
                        "dynamics": "highly collaborative"
                    }
                ]
            },
            "recommendations": [
                {
                    "target_participant": "p-123",
                    "suggestion": "Include more junior team members in discussions",
                    "rationale": "Improve team engagement and development",
                    "expected_outcome": "Increased team participation and knowledge sharing"
                }
            ],
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "assessed_by": "observer-789",
                "assessment_method": "direct observation",
                "confidence_level": 0.85,
                "tags": ["team dynamics", "leadership", "collaboration"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="social_awareness",
            version="1.0",
            description="Schema for representing social awareness, emotional intelligence, and interpersonal dynamics",
            schema={
                "type": "object",
                "required": ["timestamp", "assessment_id", "context_id", "social_context", "emotional_observations", "interpersonal_dynamics"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the social awareness assessment"
                    },
                    "assessment_id": {
                        "type": "string",
                        "description": "Unique identifier for the social awareness assessment"
                    },
                    "context_id": {
                        "type": "string",
                        "description": "Identifier of the social context being assessed"
                    },
                    "social_context": {
                        "type": "object",
                        "required": ["setting", "participants"],
                        "properties": {
                            "setting": {
                                "type": "string",
                                "description": "The social setting or environment"
                            },
                            "participants": {
                                "type": "array",
                                "description": "Participants in the social context",
                                "items": {
                                    "type": "object",
                                    "required": ["participant_id", "role"],
                                    "properties": {
                                        "participant_id": {
                                            "type": "string",
                                            "description": "Identifier for the participant"
                                        },
                                        "role": {
                                            "type": "string",
                                            "description": "Role in the social context"
                                        },
                                        "relationship_dynamics": {
                                            "type": "array",
                                            "description": "Dynamics with other participants",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            },
                            "cultural_factors": {
                                "type": "array",
                                "description": "Relevant cultural considerations",
                                "items": {"type": "string"}
                            },
                            "social_norms": {
                                "type": "array",
                                "description": "Applicable social norms",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "emotional_observations": {
                        "type": "array",
                        "description": "Observed emotional states and dynamics",
                        "items": {
                            "type": "object",
                            "required": ["subject_id", "emotional_state"],
                            "properties": {
                                "subject_id": {
                                    "type": "string",
                                    "description": "Identifier of the observed subject"
                                },
                                "emotional_state": {
                                    "type": "string",
                                    "description": "Observed emotional state"
                                },
                                "intensity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Intensity of the emotion"
                                },
                                "behavioral_indicators": {
                                    "type": "array",
                                    "description": "Observable behavioral indicators",
                                    "items": {"type": "string"}
                                },
                                "context_triggers": {
                                    "type": "array",
                                    "description": "Contextual triggers of the emotion",
                                    "items": {"type": "string"}
                                }
                            }
                        }
                    },
                    "interpersonal_dynamics": {
                        "type": "array",
                        "description": "Analysis of interpersonal dynamics",
                        "items": {
                            "type": "object",
                            "required": ["dynamic_id", "participants", "interaction_pattern"],
                            "properties": {
                                "dynamic_id": {
                                    "type": "string",
                                    "description": "Identifier for the dynamic"
                                },
                                "participants": {
                                    "type": "array",
                                    "description": "Participants involved",
                                    "items": {"type": "string"}
                                },
                                "interaction_pattern": {
                                    "type": "string",
                                    "enum": ["collaborative", "competitive", "supportive", "avoidant", "conflictual"],
                                    "description": "Pattern of interaction"
                                },
                                "power_dynamics": {
                                    "type": "string",
                                    "enum": ["balanced", "hierarchical", "dominant-submissive", "egalitarian"],
                                    "description": "Power dynamics observed"
                                },
                                "communication_style": {
                                    "type": "string",
                                    "enum": ["direct", "indirect", "assertive", "passive", "aggressive"],
                                    "description": "Style of communication"
                                },
                                "tension_points": {
                                    "type": "array",
                                    "description": "Points of tension or conflict",
                                    "items": {"type": "string"}
                                }
                            }
                        }
                    },
                    "group_dynamics": {
                        "type": "object",
                        "properties": {
                            "cohesion_level": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Level of group cohesion"
                            },
                            "power_structure": {
                                "type": "string",
                                "enum": ["hierarchical", "flat", "distributed", "centralized"],
                                "description": "Observed power structure"
                            },
                            "communication_patterns": {
                                "type": "array",
                                "description": "Patterns of group communication",
                                "items": {"type": "string"}
                            },
                            "group_mood": {
                                "type": "string",
                                "description": "Overall mood of the group"
                            },
                            "subgroup_formations": {
                                "type": "array",
                                "description": "Identified subgroups",
                                "items": {
                                    "type": "object",
                                    "required": ["members"],
                                    "properties": {
                                        "members": {
                                            "type": "array",
                                            "description": "Members of the subgroup",
                                            "items": {"type": "string"}
                                        },
                                        "dynamics": {
                                            "type": "string",
                                            "description": "Internal dynamics of the subgroup"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "recommendations": {
                        "type": "array",
                        "description": "Recommendations for social interaction",
                        "items": {
                            "type": "object",
                            "required": ["target_participant", "suggestion"],
                            "properties": {
                                "target_participant": {
                                    "type": "string",
                                    "description": "Participant the recommendation is for"
                                },
                                "suggestion": {
                                    "type": "string",
                                    "description": "Suggested action or approach"
                                },
                                "rationale": {
                                    "type": "string",
                                    "description": "Reasoning behind the recommendation"
                                },
                                "expected_outcome": {
                                    "type": "string",
                                    "description": "Expected outcome of following the recommendation"
                                }
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
                            "assessed_by": {
                                "type": "string",
                                "description": "Identifier of the assessor"
                            },
                            "assessment_method": {
                                "type": "string",
                                "enum": ["direct observation", "video analysis", "participant feedback", "survey data"],
                                "description": "Method used for assessment"
                            },
                            "confidence_level": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Overall confidence in the assessment"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {"type": "string"}
                            }
                        }
                    }
                }
            }
        ) 