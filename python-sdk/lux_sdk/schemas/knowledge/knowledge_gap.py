"""
Knowledge Gap Schema

This schema represents knowledge gaps and areas requiring further investigation,
including gap identification, impact assessment, and resolution strategies.
"""

from lux_sdk.signals import SignalSchema

KnowledgeGapSchema = SignalSchema(
    name="knowledge_gap",
    version="1.0",
    description="Schema for knowledge gaps and areas requiring investigation",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "gap_id": {
                "type": "string",
                "description": "Unique identifier for this knowledge gap"
            },
            "domain": {
                "type": "string",
                "description": "Domain or field where the gap exists"
            },
            "description": {
                "type": "string",
                "description": "Detailed description of the knowledge gap"
            },
            "identification": {
                "type": "object",
                "properties": {
                    "source": {
                        "type": "string",
                        "enum": ["analysis", "user_feedback", "expert_review", "automated_detection", "research"],
                        "description": "How the gap was identified"
                    },
                    "discovery_context": {
                        "type": "string",
                        "description": "Context in which the gap was discovered"
                    },
                    "related_concepts": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Concepts related to this knowledge gap"
                    },
                    "confidence_level": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in gap identification"
                    }
                },
                "required": ["source"]
            },
            "impact_assessment": {
                "type": "object",
                "properties": {
                    "severity": {
                        "type": "string",
                        "enum": ["critical", "high", "medium", "low"],
                        "description": "Severity of the knowledge gap"
                    },
                    "affected_areas": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "area": {
                                    "type": "string",
                                    "description": "Affected area or process"
                                },
                                "impact_description": {
                                    "type": "string",
                                    "description": "Description of the impact"
                                },
                                "impact_level": {
                                    "type": "string",
                                    "enum": ["high", "medium", "low"],
                                    "description": "Level of impact on this area"
                                }
                            },
                            "required": ["area", "impact_level"]
                        }
                    },
                    "risks": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "risk_type": {
                                    "type": "string",
                                    "description": "Type of risk"
                                },
                                "likelihood": {
                                    "type": "string",
                                    "enum": ["high", "medium", "low"],
                                    "description": "Likelihood of risk occurrence"
                                },
                                "mitigation_strategy": {
                                    "type": "string",
                                    "description": "Strategy to mitigate the risk"
                                }
                            },
                            "required": ["risk_type", "likelihood"]
                        }
                    }
                },
                "required": ["severity"]
            },
            "resolution_strategy": {
                "type": "object",
                "properties": {
                    "approach": {
                        "type": "string",
                        "enum": ["research", "experimentation", "consultation", "training", "documentation"],
                        "description": "Approach to resolve the gap"
                    },
                    "required_resources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "resource_type": {
                                    "type": "string",
                                    "description": "Type of resource needed"
                                },
                                "quantity": {
                                    "type": "number",
                                    "description": "Quantity of resource needed"
                                },
                                "availability": {
                                    "type": "string",
                                    "enum": ["available", "partially_available", "unavailable"],
                                    "description": "Resource availability"
                                }
                            },
                            "required": ["resource_type"]
                        }
                    },
                    "timeline": {
                        "type": "object",
                        "properties": {
                            "estimated_duration": {
                                "type": "string",
                                "description": "Estimated time to resolve"
                            },
                            "priority": {
                                "type": "string",
                                "enum": ["immediate", "high", "medium", "low"],
                                "description": "Resolution priority"
                            },
                            "milestones": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "description": {
                                            "type": "string",
                                            "description": "Milestone description"
                                        },
                                        "target_date": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Target completion date"
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                "required": ["approach"]
            },
            "progress_tracking": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["identified", "in_progress", "resolved", "blocked"],
                        "description": "Current status of resolution"
                    },
                    "progress_indicators": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "indicator": {
                                    "type": "string",
                                    "description": "Progress indicator"
                                },
                                "current_value": {
                                    "type": "number",
                                    "description": "Current value"
                                },
                                "target_value": {
                                    "type": "number",
                                    "description": "Target value"
                                }
                            }
                        }
                    },
                    "blockers": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "description": {
                                    "type": "string",
                                    "description": "Blocker description"
                                },
                                "impact": {
                                    "type": "string",
                                    "enum": ["high", "medium", "low"],
                                    "description": "Impact of the blocker"
                                },
                                "resolution_plan": {
                                    "type": "string",
                                    "description": "Plan to resolve the blocker"
                                }
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the knowledge gap record"
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
                    "assigned_to": {
                        "type": "string",
                        "description": "Person assigned to resolve the gap"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "gap_id",
            "domain",
            "description",
            "identification",
            "impact_assessment"
        ]
    }
) 