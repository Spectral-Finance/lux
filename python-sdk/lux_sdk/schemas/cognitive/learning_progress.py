"""
Schema for tracking learning progress and cognitive development.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class LearningProgressSchema(SignalSchema):
    """Schema for tracking and analyzing learning progress and cognitive development.
    
    This schema defines the structure for documenting and analyzing learning progress,
    including cognitive domains, metrics, milestones, and recommendations.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "progress_id": "prog_123",
            "learner_id": "learner_456",
            "cognitive_domain": {
                "name": "Critical Thinking",
                "category": "Higher-Order Thinking",
                "level": "Advanced"
            },
            "learning_metrics": {
                "comprehension": 0.85,
                "retention": 0.78,
                "application": 0.92,
                "analysis": 0.88
            },
            "milestones": [{
                "milestone_id": "ms_1",
                "name": "Complex Problem Analysis",
                "completion_date": "2024-04-02",
                "proficiency_level": "Expert"
            }],
            "challenges": [{
                "challenge_type": "Time Management",
                "description": "Difficulty balancing multiple concepts",
                "status": "in_progress",
                "interventions": [
                    "Weekly planning sessions",
                    "Priority matrix implementation"
                ]
            }],
            "recommendations": [{
                "focus_area": "Pattern Recognition",
                "suggestion": "Practice with diverse problem sets",
                "priority": "high",
                "expected_outcome": "Improved analytical speed"
            }],
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "updated_at": "2024-04-03T15:30:00Z",
                "source": "cognitive_assessment_v2",
                "version": "1.0",
                "tags": ["critical_thinking", "advanced", "cognitive"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="learning_progress",
            version="1.0",
            description="Schema for tracking and analyzing learning progress and cognitive development",
            schema={
                "type": "object",
                "required": ["timestamp", "progress_id", "learner_id", "cognitive_domain", "learning_metrics", "milestones"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the learning progress record"
                    },
                    "progress_id": {
                        "type": "string",
                        "description": "Unique identifier for the learning progress record"
                    },
                    "learner_id": {
                        "type": "string",
                        "description": "Identifier of the learner"
                    },
                    "cognitive_domain": {
                        "type": "object",
                        "description": "Domain of cognitive development being tracked",
                        "required": ["name", "category"],
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Name of the cognitive domain"
                            },
                            "category": {
                                "type": "string",
                                "description": "Category of cognitive skills"
                            },
                            "level": {
                                "type": "string",
                                "description": "Current level in the domain"
                            }
                        }
                    },
                    "learning_metrics": {
                        "type": "object",
                        "description": "Quantitative measures of learning progress",
                        "properties": {
                            "comprehension": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Score for understanding of concepts"
                            },
                            "retention": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Score for information retention"
                            },
                            "application": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Score for practical application"
                            },
                            "analysis": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Score for analytical thinking"
                            }
                        }
                    },
                    "milestones": {
                        "type": "array",
                        "description": "Learning milestones achieved",
                        "items": {
                            "type": "object",
                            "required": ["milestone_id", "name"],
                            "properties": {
                                "milestone_id": {
                                    "type": "string",
                                    "description": "Identifier of the milestone"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Name of the milestone"
                                },
                                "completion_date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Date when milestone was achieved"
                                },
                                "proficiency_level": {
                                    "type": "string",
                                    "description": "Level of proficiency demonstrated"
                                }
                            }
                        }
                    },
                    "challenges": {
                        "type": "array",
                        "description": "Learning challenges and obstacles",
                        "items": {
                            "type": "object",
                            "required": ["challenge_type", "description"],
                            "properties": {
                                "challenge_type": {
                                    "type": "string",
                                    "description": "Type of learning challenge"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the challenge"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["not_started", "in_progress", "resolved", "ongoing"],
                                    "description": "Current status of the challenge"
                                },
                                "interventions": {
                                    "type": "array",
                                    "description": "Interventions applied",
                                    "items": {
                                        "type": "string"
                                    }
                                }
                            }
                        }
                    },
                    "recommendations": {
                        "type": "array",
                        "description": "Recommendations for improvement",
                        "items": {
                            "type": "object",
                            "required": ["focus_area", "suggestion"],
                            "properties": {
                                "focus_area": {
                                    "type": "string",
                                    "description": "Area needing attention"
                                },
                                "suggestion": {
                                    "type": "string",
                                    "description": "Specific recommendation"
                                },
                                "priority": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high", "critical"],
                                    "description": "Priority level of the recommendation"
                                },
                                "expected_outcome": {
                                    "type": "string",
                                    "description": "Expected result of following the recommendation"
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the learning progress",
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
                            "source": {
                                "type": "string",
                                "description": "Source of the learning progress data"
                            },
                            "version": {
                                "type": "string",
                                "description": "Version of the assessment"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    }
                }
            }
        ) 