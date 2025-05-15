"""
Learning Process Schema

This schema defines the structure for representing learning processes,
including experience acquisition, knowledge integration, skill development,
and performance improvement tracking.

Example:
{
    "timestamp": "2024-04-03T12:34:56Z",
    "learning_id": "learn-123",
    "learning_type": "reinforcement",
    "context": {
        "domain": "game_strategy",
        "environment": "chess_game",
        "difficulty_level": "intermediate"
    },
    "learning_objective": {
        "goal": "Improve end-game positioning",
        "success_criteria": ["win_rate_increase", "position_advantage"],
        "target_metrics": {
            "win_rate": 0.6,
            "position_score": 8.5
        }
    },
    "experiences": [
        {
            "id": "exp-1",
            "type": "game_round",
            "outcome": "success",
            "feedback": {
                "reward": 1.0,
                "observations": ["good_piece_coordination", "time_management"]
            },
            "metadata": {
                "duration": 300,
                "opponent_level": "expert"
            }
        }
    ],
    "learning_progress": {
        "current_performance": {
            "win_rate": 0.55,
            "position_score": 7.8
        },
        "improvement_rate": 0.15,
        "learning_curve": [
            {
                "timestamp": "2024-04-03T10:00:00Z",
                "metrics": {"win_rate": 0.45, "position_score": 6.5}
            },
            {
                "timestamp": "2024-04-03T11:00:00Z",
                "metrics": {"win_rate": 0.50, "position_score": 7.2}
            }
        ]
    },
    "adaptations": [
        {
            "id": "adapt-1",
            "type": "strategy_adjustment",
            "description": "Increased focus on pawn structure",
            "trigger": "repeated_endgame_losses",
            "effectiveness": 0.8
        }
    ],
    "metadata": {
        "learning_duration": 3600,
        "resources_consumed": ["compute_time", "training_data"],
        "version": "1.0"
    }
}
"""

from lux_sdk.signals import SignalSchema

LearningProcessSchema = SignalSchema(
    name="learning_process",
    version="1.0",
    description="Schema for representing learning and adaptation processes",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "When the learning process occurred"
            },
            "learning_id": {
                "type": "string",
                "description": "Unique identifier for the learning process"
            },
            "learning_type": {
                "type": "string",
                "enum": ["reinforcement", "supervised", "unsupervised", "transfer", "active"],
                "description": "The type of learning being employed"
            },
            "context": {
                "type": "object",
                "properties": {
                    "domain": {
                        "type": "string",
                        "description": "Domain or field of learning"
                    },
                    "environment": {
                        "type": "string",
                        "description": "Learning environment or context"
                    },
                    "difficulty_level": {
                        "type": "string",
                        "description": "Difficulty level of the learning task"
                    }
                },
                "required": ["domain", "environment"]
            },
            "learning_objective": {
                "type": "object",
                "properties": {
                    "goal": {
                        "type": "string",
                        "description": "Primary learning goal"
                    },
                    "success_criteria": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Criteria for successful learning"
                    },
                    "target_metrics": {
                        "type": "object",
                        "additionalProperties": {
                            "type": "number"
                        },
                        "description": "Target performance metrics"
                    }
                },
                "required": ["goal", "success_criteria"]
            },
            "experiences": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": "Experience identifier"
                        },
                        "type": {
                            "type": "string",
                            "description": "Type of experience"
                        },
                        "outcome": {
                            "type": "string",
                            "enum": ["success", "failure", "neutral"],
                            "description": "Outcome of the experience"
                        },
                        "feedback": {
                            "type": "object",
                            "properties": {
                                "reward": {
                                    "type": "number",
                                    "description": "Numerical reward value"
                                },
                                "observations": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Observed factors"
                                }
                            }
                        },
                        "metadata": {
                            "type": "object",
                            "additionalProperties": true,
                            "description": "Additional experience metadata"
                        }
                    },
                    "required": ["id", "type", "outcome"]
                },
                "description": "List of learning experiences"
            },
            "learning_progress": {
                "type": "object",
                "properties": {
                    "current_performance": {
                        "type": "object",
                        "additionalProperties": {
                            "type": "number"
                        },
                        "description": "Current performance metrics"
                    },
                    "improvement_rate": {
                        "type": "number",
                        "minimum": -1,
                        "maximum": 1,
                        "description": "Rate of improvement"
                    },
                    "learning_curve": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time"
                                },
                                "metrics": {
                                    "type": "object",
                                    "additionalProperties": {
                                        "type": "number"
                                    }
                                }
                            },
                            "required": ["timestamp", "metrics"]
                        },
                        "description": "Historical learning progress"
                    }
                },
                "required": ["current_performance"]
            },
            "adaptations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": "Adaptation identifier"
                        },
                        "type": {
                            "type": "string",
                            "description": "Type of adaptation"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the adaptation"
                        },
                        "trigger": {
                            "type": "string",
                            "description": "What triggered the adaptation"
                        },
                        "effectiveness": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Effectiveness of the adaptation"
                        }
                    },
                    "required": ["id", "type", "description"]
                },
                "description": "List of adaptations made during learning"
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "learning_duration": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Duration of learning process in seconds"
                    },
                    "resources_consumed": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Resources used during learning"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the learning process"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "learning_id",
            "learning_type",
            "context",
            "learning_objective",
            "experiences",
            "learning_progress"
        ]
    }
) 