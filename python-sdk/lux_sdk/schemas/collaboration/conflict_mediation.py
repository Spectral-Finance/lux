"""
Conflict Mediation Schema

This schema represents conflict mediation processes in collaborative environments,
including conflict identification, resolution strategies, and outcomes.
"""

from lux_sdk.signals import SignalSchema

ConflictMediationSchema = SignalSchema(
    name="conflict_mediation",
    version="1.0",
    description="Schema for managing and tracking conflict mediation processes",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "mediation_id": {
                "type": "string",
                "description": "Unique identifier for this mediation process"
            },
            "conflict_type": {
                "type": "string",
                "enum": ["resource", "task", "process", "relationship", "technical", "strategic"],
                "description": "Type of conflict being mediated"
            },
            "severity": {
                "type": "string",
                "enum": ["low", "medium", "high", "critical"],
                "description": "Severity level of the conflict"
            },
            "parties": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "party_id": {
                            "type": "string",
                            "description": "Identifier for the involved party"
                        },
                        "role": {
                            "type": "string",
                            "description": "Role in the conflict"
                        },
                        "position": {
                            "type": "string",
                            "description": "Party's position or stance"
                        },
                        "interests": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Underlying interests"
                            }
                        }
                    },
                    "required": ["party_id", "role", "position"]
                }
            },
            "issues": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "issue_id": {
                            "type": "string",
                            "description": "Identifier for the issue"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the issue"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high"],
                            "description": "Priority level of the issue"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["identified", "analyzing", "negotiating", "resolved"],
                            "description": "Current status of the issue"
                        }
                    },
                    "required": ["issue_id", "description", "priority", "status"]
                }
            },
            "mediation_process": {
                "type": "object",
                "properties": {
                    "approach": {
                        "type": "string",
                        "enum": ["facilitative", "evaluative", "transformative", "directive"],
                        "description": "Mediation approach being used"
                    },
                    "stages": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "stage_name": {
                                    "type": "string",
                                    "description": "Name of the mediation stage"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["pending", "in_progress", "completed"],
                                    "description": "Status of this stage"
                                },
                                "outcomes": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Outcomes from this stage"
                                    }
                                }
                            },
                            "required": ["stage_name", "status"]
                        }
                    },
                    "techniques": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Mediation techniques being used"
                        }
                    }
                },
                "required": ["approach", "stages"]
            },
            "resolution": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["pending", "partial", "complete", "failed"],
                        "description": "Status of conflict resolution"
                    },
                    "agreements": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "agreement_id": {
                                    "type": "string",
                                    "description": "Identifier for the agreement"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the agreement"
                                },
                                "parties_involved": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "IDs of parties in agreement"
                                    }
                                }
                            },
                            "required": ["agreement_id", "description", "parties_involved"]
                        }
                    },
                    "follow_up_actions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "action": {
                                    "type": "string",
                                    "description": "Action to be taken"
                                },
                                "assignee": {
                                    "type": "string",
                                    "description": "ID of responsible party"
                                },
                                "deadline": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Deadline for the action"
                                }
                            },
                            "required": ["action", "assignee"]
                        }
                    }
                },
                "required": ["status"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "mediator": {
                        "type": "string",
                        "description": "ID of the mediator"
                    },
                    "start_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When mediation started"
                    },
                    "end_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When mediation ended"
                    },
                    "confidentiality_level": {
                        "type": "string",
                        "enum": ["public", "private", "restricted"],
                        "description": "Level of confidentiality"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "mediation_id", "conflict_type", "severity", "parties", "issues", "mediation_process"]
    }
) 