"""
Coordination Protocol Schema

This schema represents coordination protocols and interaction patterns
in collaborative systems, including communication rules, synchronization,
and decision-making processes.
"""

from lux_sdk.signals import SignalSchema

CoordinationProtocolSchema = SignalSchema(
    name="coordination_protocol",
    version="1.0",
    description="Schema for coordination protocols and interaction patterns",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "protocol_id": {
                "type": "string",
                "description": "Unique identifier for this coordination protocol"
            },
            "name": {
                "type": "string",
                "description": "Name of the coordination protocol"
            },
            "description": {
                "type": "string",
                "description": "Description of the protocol's purpose and function"
            },
            "type": {
                "type": "string",
                "enum": [
                    "synchronization",
                    "decision_making",
                    "resource_allocation",
                    "task_assignment",
                    "conflict_resolution",
                    "information_sharing",
                    "consensus_building",
                    "other"
                ],
                "description": "Type of coordination protocol"
            },
            "participants": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "participant_id": {
                            "type": "string",
                            "description": "Unique identifier for the participant"
                        },
                        "role": {
                            "type": "string",
                            "description": "Role in the protocol"
                        },
                        "permissions": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "enum": [
                                    "initiate",
                                    "respond",
                                    "approve",
                                    "reject",
                                    "modify",
                                    "observe",
                                    "escalate"
                                ],
                                "description": "Permitted actions"
                            }
                        }
                    },
                    "required": ["participant_id", "role", "permissions"]
                }
            },
            "rules": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "rule_id": {
                            "type": "string",
                            "description": "Unique identifier for the rule"
                        },
                        "type": {
                            "type": "string",
                            "enum": [
                                "precondition",
                                "postcondition",
                                "invariant",
                                "constraint",
                                "trigger",
                                "action"
                            ],
                            "description": "Type of rule"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the rule"
                        },
                        "condition": {
                            "type": "string",
                            "description": "Formal condition expression"
                        },
                        "priority": {
                            "type": "integer",
                            "minimum": 1,
                            "maximum": 10,
                            "description": "Priority level of the rule"
                        }
                    },
                    "required": ["rule_id", "type", "description"]
                }
            },
            "states": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "state_id": {
                            "type": "string",
                            "description": "Unique identifier for the state"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the state"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["initial", "intermediate", "final", "error"],
                            "description": "Type of state"
                        },
                        "actions": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "action_id": {
                                        "type": "string",
                                        "description": "Unique identifier for the action"
                                    },
                                    "type": {
                                        "type": "string",
                                        "description": "Type of action"
                                    },
                                    "roles": {
                                        "type": "array",
                                        "items": {
                                            "type": "string",
                                            "description": "Roles that can perform this action"
                                        }
                                    }
                                },
                                "required": ["action_id", "type", "roles"]
                            }
                        }
                    },
                    "required": ["state_id", "name", "type"]
                }
            },
            "transitions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "transition_id": {
                            "type": "string",
                            "description": "Unique identifier for the transition"
                        },
                        "from_state": {
                            "type": "string",
                            "description": "Source state ID"
                        },
                        "to_state": {
                            "type": "string",
                            "description": "Target state ID"
                        },
                        "trigger": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of trigger"
                                },
                                "condition": {
                                    "type": "string",
                                    "description": "Condition for the transition"
                                }
                            },
                            "required": ["type"]
                        }
                    },
                    "required": ["transition_id", "from_state", "to_state"]
                }
            },
            "timeouts": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "state_id": {
                            "type": "string",
                            "description": "State ID where timeout applies"
                        },
                        "duration": {
                            "type": "number",
                            "description": "Timeout duration"
                        },
                        "unit": {
                            "type": "string",
                            "enum": ["seconds", "minutes", "hours", "days"],
                            "description": "Unit of timeout duration"
                        },
                        "action": {
                            "type": "string",
                            "description": "Action to take on timeout"
                        }
                    },
                    "required": ["state_id", "duration", "unit", "action"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "version": {
                        "type": "string",
                        "description": "Version of the protocol"
                    },
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the protocol"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "active", "deprecated", "retired"],
                        "description": "Current status of the protocol"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "protocol_id",
            "name",
            "type",
            "participants",
            "rules",
            "states"
        ]
    }
) 