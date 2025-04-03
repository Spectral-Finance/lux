"""
Schema for representing consensus building processes and outcomes.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ConsensusBuildingSchema(SignalSchema):
    """Schema for representing consensus building processes and outcomes.
    
    This schema defines the structure for documenting and managing consensus building
    processes, including stakeholders, stages, proposals, and outcomes.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "process_id": "proc_123",
            "topic_id": "topic_456",
            "topic": {
                "title": "Product Roadmap 2024",
                "description": "Define product priorities for 2024",
                "scope": "Annual planning",
                "context": "Product development",
                "objectives": [
                    "Align on key features",
                    "Set delivery timelines"
                ],
                "constraints": [
                    "Budget limitations",
                    "Resource availability"
                ]
            },
            "stakeholders": [{
                "stakeholder_id": "user_789",
                "role": "Product Manager",
                "influence_level": 0.8,
                "interests": ["User experience", "Market fit"],
                "requirements": ["Data-driven decisions"],
                "participation_status": "active"
            }],
            "process_stages": [{
                "stage_id": "stage_1",
                "name": "Information Gathering",
                "status": "completed",
                "start_date": "2024-04-01",
                "end_date": "2024-04-02",
                "activities": [{
                    "activity_id": "act_1",
                    "description": "Stakeholder interviews",
                    "participants": ["user_789", "user_790"],
                    "outcomes": ["Identified key priorities"]
                }]
            }],
            "proposals": [{
                "proposal_id": "prop_1",
                "title": "Focus on AI Features",
                "description": "Prioritize AI-driven capabilities",
                "proposer": "user_789",
                "benefits": ["Market differentiation"],
                "drawbacks": ["Technical complexity"],
                "support_level": 0.75,
                "feedback": [{
                    "stakeholder_id": "user_790",
                    "position": "support",
                    "comments": "Aligns with market trends"
                }]
            }],
            "decision_making": {
                "method": "weighted_voting",
                "criteria": [{
                    "criterion": "Technical feasibility",
                    "weight": 0.4
                }],
                "voting_rules": {
                    "method": "majority",
                    "threshold": 0.75,
                    "deadline": "2024-04-05T17:00:00Z"
                }
            },
            "outcomes": {
                "status": "achieved",
                "agreement_level": 0.85,
                "decision": "Proceed with AI features",
                "rationale": "Strong market demand",
                "dissenting_views": [{
                    "stakeholder_id": "user_791",
                    "reason": "Resource concerns",
                    "alternative": "Focus on core features"
                }],
                "next_steps": [
                    "Create detailed specifications",
                    "Assign resources"
                ]
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "facilitator": "user_792",
                "priority": "high",
                "status": "in_progress",
                "documentation": ["meeting_notes.pdf"],
                "tags": ["product", "planning", "2024"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="consensus_building",
            version="1.0",
            description="Schema for representing consensus building processes and their outcomes",
            schema={
                "type": "object",
                "required": ["timestamp", "process_id", "topic_id", "topic", "stakeholders", "process_stages"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the consensus building process"
                    },
                    "process_id": {
                        "type": "string",
                        "description": "Unique identifier for the consensus building process"
                    },
                    "topic_id": {
                        "type": "string",
                        "description": "Identifier of the topic requiring consensus"
                    },
                    "topic": {
                        "type": "object",
                        "description": "Details of the topic requiring consensus",
                        "required": ["title", "description"],
                        "properties": {
                            "title": {
                                "type": "string",
                                "description": "Title of the topic"
                            },
                            "description": {
                                "type": "string",
                                "description": "Description of the topic"
                            },
                            "scope": {
                                "type": "string",
                                "description": "Scope of the decision"
                            },
                            "context": {
                                "type": "string",
                                "description": "Context of the topic"
                            },
                            "objectives": {
                                "type": "array",
                                "description": "Objectives to be achieved",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "constraints": {
                                "type": "array",
                                "description": "Constraints to consider",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "stakeholders": {
                        "type": "array",
                        "description": "Involved stakeholders",
                        "items": {
                            "type": "object",
                            "required": ["stakeholder_id", "role"],
                            "properties": {
                                "stakeholder_id": {
                                    "type": "string",
                                    "description": "Identifier of the stakeholder"
                                },
                                "role": {
                                    "type": "string",
                                    "description": "Role in the process"
                                },
                                "influence_level": {
                                    "type": "number",
                                    "description": "Level of influence",
                                    "minimum": 0,
                                    "maximum": 1
                                },
                                "interests": {
                                    "type": "array",
                                    "description": "Stakeholder's interests",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "requirements": {
                                    "type": "array",
                                    "description": "Stakeholder's requirements",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "participation_status": {
                                    "type": "string",
                                    "enum": ["active", "inactive", "pending", "withdrawn"],
                                    "description": "Status of participation"
                                }
                            }
                        }
                    },
                    "process_stages": {
                        "type": "array",
                        "description": "Stages of the consensus building process",
                        "items": {
                            "type": "object",
                            "required": ["stage_id", "name", "status"],
                            "properties": {
                                "stage_id": {
                                    "type": "string",
                                    "description": "Identifier for the stage"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Name of the stage"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["not_started", "in_progress", "completed", "blocked"],
                                    "description": "Current status"
                                },
                                "start_date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "Start date of the stage"
                                },
                                "end_date": {
                                    "type": "string",
                                    "format": "date",
                                    "description": "End date of the stage"
                                },
                                "activities": {
                                    "type": "array",
                                    "description": "Activities in this stage",
                                    "items": {
                                        "type": "object",
                                        "required": ["activity_id", "description"],
                                        "properties": {
                                            "activity_id": {
                                                "type": "string",
                                                "description": "Activity identifier"
                                            },
                                            "description": {
                                                "type": "string",
                                                "description": "Activity description"
                                            },
                                            "participants": {
                                                "type": "array",
                                                "description": "Involved participants",
                                                "items": {
                                                    "type": "string"
                                                }
                                            },
                                            "outcomes": {
                                                "type": "array",
                                                "description": "Activity outcomes",
                                                "items": {
                                                    "type": "string"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "proposals": {
                        "type": "array",
                        "description": "Proposed solutions or decisions",
                        "items": {
                            "type": "object",
                            "required": ["proposal_id", "title", "description"],
                            "properties": {
                                "proposal_id": {
                                    "type": "string",
                                    "description": "Identifier for the proposal"
                                },
                                "title": {
                                    "type": "string",
                                    "description": "Title of the proposal"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the proposal"
                                },
                                "proposer": {
                                    "type": "string",
                                    "description": "Identifier of the proposer"
                                },
                                "benefits": {
                                    "type": "array",
                                    "description": "Expected benefits",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "drawbacks": {
                                    "type": "array",
                                    "description": "Potential drawbacks",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "support_level": {
                                    "type": "number",
                                    "description": "Level of support",
                                    "minimum": 0,
                                    "maximum": 1
                                },
                                "feedback": {
                                    "type": "array",
                                    "description": "Stakeholder feedback",
                                    "items": {
                                        "type": "object",
                                        "required": ["stakeholder_id", "position"],
                                        "properties": {
                                            "stakeholder_id": {
                                                "type": "string",
                                                "description": "Feedback provider"
                                            },
                                            "position": {
                                                "type": "string",
                                                "enum": ["support", "oppose", "neutral", "abstain"],
                                                "description": "Position on the proposal"
                                            },
                                            "comments": {
                                                "type": "string",
                                                "description": "Detailed comments"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "decision_making": {
                        "type": "object",
                        "description": "Decision making process",
                        "properties": {
                            "method": {
                                "type": "string",
                                "enum": ["consensus", "majority", "weighted_voting", "unanimous"],
                                "description": "Method of decision making"
                            },
                            "criteria": {
                                "type": "array",
                                "description": "Decision criteria",
                                "items": {
                                    "type": "object",
                                    "required": ["criterion", "weight"],
                                    "properties": {
                                        "criterion": {
                                            "type": "string",
                                            "description": "Decision criterion"
                                        },
                                        "weight": {
                                            "type": "number",
                                            "description": "Weight of the criterion",
                                            "minimum": 0,
                                            "maximum": 1
                                        }
                                    }
                                }
                            },
                            "voting_rules": {
                                "type": "object",
                                "description": "Rules for voting",
                                "properties": {
                                    "method": {
                                        "type": "string",
                                        "description": "Voting method"
                                    },
                                    "threshold": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Required threshold for approval"
                                    },
                                    "deadline": {
                                        "type": "string",
                                        "format": "date-time",
                                        "description": "Voting deadline"
                                    }
                                }
                            }
                        }
                    },
                    "outcomes": {
                        "type": "object",
                        "description": "Consensus building outcomes",
                        "properties": {
                            "status": {
                                "type": "string",
                                "enum": ["pending", "in_progress", "achieved", "failed"],
                                "description": "Overall status of consensus"
                            },
                            "agreement_level": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Level of agreement achieved"
                            },
                            "decision": {
                                "type": "string",
                                "description": "Final decision or agreement"
                            },
                            "rationale": {
                                "type": "string",
                                "description": "Rationale for the decision"
                            },
                            "dissenting_views": {
                                "type": "array",
                                "description": "Documented dissenting views",
                                "items": {
                                    "type": "object",
                                    "required": ["stakeholder_id", "reason"],
                                    "properties": {
                                        "stakeholder_id": {
                                            "type": "string",
                                            "description": "Dissenting stakeholder"
                                        },
                                        "reason": {
                                            "type": "string",
                                            "description": "Reason for dissent"
                                        },
                                        "alternative": {
                                            "type": "string",
                                            "description": "Proposed alternative"
                                        }
                                    }
                                }
                            },
                            "next_steps": {
                                "type": "array",
                                "description": "Agreed next steps",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the consensus building process",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "facilitator": {
                                "type": "string",
                                "description": "Process facilitator"
                            },
                            "priority": {
                                "type": "string",
                                "enum": ["low", "medium", "high", "critical"],
                                "description": "Priority level"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "completed", "archived"],
                                "description": "Current status"
                            },
                            "documentation": {
                                "type": "array",
                                "description": "Related documentation",
                                "items": {
                                    "type": "string"
                                }
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