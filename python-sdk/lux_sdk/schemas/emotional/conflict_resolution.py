"""
Conflict Resolution Schema

This schema represents conflict resolution processes and outcomes,
including emotional dynamics, resolution strategies, and reconciliation.
"""

from lux_sdk.signals import SignalSchema

ConflictResolutionSchema = SignalSchema(
    name="conflict_resolution",
    version="1.0",
    description="Schema for emotional conflict resolution processes and outcomes",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "conflict_id": {
                "type": "string",
                "description": "Unique identifier for this conflict"
            },
            "participants": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "participant_id": {
                            "type": "string",
                            "description": "Identifier for the participant"
                        },
                        "role": {
                            "type": "string",
                            "description": "Role in the conflict"
                        },
                        "emotional_state": {
                            "type": "object",
                            "properties": {
                                "primary_emotion": {
                                    "type": "string",
                                    "description": "Primary emotion being experienced"
                                },
                                "intensity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 10,
                                    "description": "Intensity of emotional response"
                                },
                                "triggers": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Factors triggering emotional response"
                                    }
                                }
                            },
                            "required": ["primary_emotion", "intensity"]
                        }
                    },
                    "required": ["participant_id", "role", "emotional_state"]
                }
            },
            "conflict_details": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["interpersonal", "group", "organizational", "cultural", "other"],
                        "description": "Type of conflict"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the conflict"
                    },
                    "severity": {
                        "type": "string",
                        "enum": ["low", "moderate", "high", "critical"],
                        "description": "Severity level of the conflict"
                    },
                    "duration": {
                        "type": "object",
                        "properties": {
                            "start_date": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When the conflict began"
                            },
                            "resolution_date": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When the conflict was resolved"
                            }
                        },
                        "required": ["start_date"]
                    }
                },
                "required": ["type", "description", "severity"]
            },
            "resolution_process": {
                "type": "object",
                "properties": {
                    "approach": {
                        "type": "string",
                        "enum": ["mediation", "negotiation", "facilitation", "arbitration", "other"],
                        "description": "Approach used for resolution"
                    },
                    "strategies": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "strategy_type": {
                                    "type": "string",
                                    "description": "Type of resolution strategy"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the strategy"
                                },
                                "effectiveness": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 10,
                                    "description": "Effectiveness rating"
                                }
                            },
                            "required": ["strategy_type", "description"]
                        }
                    },
                    "interventions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of intervention"
                                },
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "When intervention occurred"
                                },
                                "outcome": {
                                    "type": "string",
                                    "description": "Outcome of the intervention"
                                }
                            },
                            "required": ["type", "timestamp"]
                        }
                    }
                },
                "required": ["approach", "strategies"]
            },
            "outcomes": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["resolved", "partially_resolved", "unresolved", "escalated"],
                        "description": "Current status of the conflict"
                    },
                    "resolution_details": {
                        "type": "object",
                        "properties": {
                            "agreements": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "Agreements reached"
                                }
                            },
                            "action_items": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "description": {
                                            "type": "string",
                                            "description": "Action item description"
                                        },
                                        "assignee": {
                                            "type": "string",
                                            "description": "Person responsible"
                                        },
                                        "deadline": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Completion deadline"
                                        }
                                    },
                                    "required": ["description", "assignee"]
                                }
                            }
                        }
                    },
                    "satisfaction_levels": {
                        "type": "object",
                        "properties": {
                            "overall": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 10,
                                "description": "Overall satisfaction with resolution"
                            },
                            "by_participant": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "participant_id": {
                                            "type": "string",
                                            "description": "Participant identifier"
                                        },
                                        "satisfaction_score": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 10,
                                            "description": "Individual satisfaction score"
                                        }
                                    },
                                    "required": ["participant_id", "satisfaction_score"]
                                }
                            }
                        },
                        "required": ["overall"]
                    }
                },
                "required": ["status"]
            },
            "follow_up": {
                "type": "object",
                "properties": {
                    "monitoring_plan": {
                        "type": "object",
                        "properties": {
                            "frequency": {
                                "type": "string",
                                "description": "Frequency of follow-up"
                            },
                            "duration": {
                                "type": "string",
                                "description": "Duration of monitoring"
                            },
                            "metrics": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "Metrics to monitor"
                                }
                            }
                        }
                    },
                    "prevention_strategies": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "strategy": {
                                    "type": "string",
                                    "description": "Prevention strategy"
                                },
                                "implementation_plan": {
                                    "type": "string",
                                    "description": "How to implement the strategy"
                                }
                            },
                            "required": ["strategy", "implementation_plan"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "facilitator_id": {
                        "type": "string",
                        "description": "ID of conflict resolution facilitator"
                    },
                    "confidentiality_level": {
                        "type": "string",
                        "enum": ["public", "private", "restricted"],
                        "description": "Level of confidentiality"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Relevant tags"
                        }
                    },
                    "notes": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Additional notes"
                        }
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "conflict_id",
            "participants",
            "conflict_details",
            "resolution_process",
            "outcomes"
        ]
    }
) 