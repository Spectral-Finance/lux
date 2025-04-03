"""
Ethical Justification Schema

This schema represents the structure for documenting ethical justifications
for decisions, actions, or policies, including reasoning, principles applied,
and stakeholder considerations.
"""

from lux_sdk.signals import SignalSchema

EthicalJustificationSchema = SignalSchema(
    name="ethical_justification",
    version="1.0",
    description="Schema for documenting ethical justifications",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "justification_id": {
                "type": "string",
                "description": "Unique identifier for this ethical justification"
            },
            "context": {
                "type": "object",
                "properties": {
                    "decision_type": {
                        "type": "string",
                        "enum": [
                            "policy",
                            "system_design",
                            "feature_implementation",
                            "data_usage",
                            "algorithm_deployment",
                            "resource_allocation",
                            "other"
                        ],
                        "description": "Type of decision being justified"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the decision or action"
                    },
                    "scope": {
                        "type": "string",
                        "description": "Scope of impact"
                    },
                    "urgency": {
                        "type": "string",
                        "enum": ["critical", "high", "medium", "low"],
                        "description": "Urgency of decision"
                    }
                },
                "required": ["decision_type", "description"]
            },
            "ethical_principles": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "principle_id": {
                            "type": "string",
                            "description": "Reference to ethical principle"
                        },
                        "relevance": {
                            "type": "string",
                            "description": "How principle applies"
                        },
                        "alignment": {
                            "type": "object",
                            "properties": {
                                "level": {
                                    "type": "string",
                                    "enum": ["strong", "moderate", "weak", "potential_conflict"],
                                    "description": "Level of alignment with principle"
                                },
                                "explanation": {
                                    "type": "string",
                                    "description": "Explanation of alignment"
                                }
                            },
                            "required": ["level", "explanation"]
                        }
                    },
                    "required": ["principle_id", "relevance", "alignment"]
                }
            },
            "stakeholder_analysis": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "stakeholder_group": {
                            "type": "string",
                            "description": "Identified stakeholder group"
                        },
                        "interests": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Stakeholder interests"
                        },
                        "impact": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["positive", "negative", "mixed", "neutral"],
                                    "description": "Type of impact"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of impact"
                                },
                                "severity": {
                                    "type": "string",
                                    "enum": ["high", "medium", "low"],
                                    "description": "Impact severity"
                                }
                            },
                            "required": ["type", "description"]
                        }
                    },
                    "required": ["stakeholder_group", "impact"]
                }
            },
            "reasoning": {
                "type": "object",
                "properties": {
                    "arguments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "argument_id": {
                                    "type": "string",
                                    "description": "Identifier for argument"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["supporting", "opposing", "mitigating"],
                                    "description": "Type of argument"
                                },
                                "premise": {
                                    "type": "string",
                                    "description": "Main premise of argument"
                                },
                                "evidence": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Supporting evidence"
                                }
                            },
                            "required": ["argument_id", "type", "premise"]
                        }
                    },
                    "alternatives_considered": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "alternative": {
                                    "type": "string",
                                    "description": "Alternative option"
                                },
                                "pros": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Advantages"
                                },
                                "cons": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Disadvantages"
                                },
                                "reason_rejected": {
                                    "type": "string",
                                    "description": "Why alternative was not chosen"
                                }
                            },
                            "required": ["alternative", "reason_rejected"]
                        }
                    }
                },
                "required": ["arguments"]
            },
            "risk_assessment": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "risk_type": {
                            "type": "string",
                            "description": "Type of ethical risk"
                        },
                        "likelihood": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Risk likelihood"
                        },
                        "impact": {
                            "type": "string",
                            "enum": ["severe", "moderate", "minor"],
                            "description": "Potential impact"
                        },
                        "mitigation_strategy": {
                            "type": "string",
                            "description": "Strategy to mitigate risk"
                        }
                    },
                    "required": ["risk_type", "likelihood", "impact"]
                }
            },
            "decision": {
                "type": "object",
                "properties": {
                    "outcome": {
                        "type": "string",
                        "enum": ["approved", "rejected", "modified"],
                        "description": "Decision outcome"
                    },
                    "rationale": {
                        "type": "string",
                        "description": "Final rationale for decision"
                    },
                    "conditions": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Conditions or requirements"
                    },
                    "review_period": {
                        "type": "string",
                        "description": "When to review decision"
                    }
                },
                "required": ["outcome", "rationale"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of justification"
                    },
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
                    "version": {
                        "type": "string",
                        "description": "Version of justification"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "final", "superseded"],
                        "description": "Status of justification"
                    },
                    "references": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source": {
                                    "type": "string",
                                    "description": "Reference source"
                                },
                                "relevance": {
                                    "type": "string",
                                    "description": "Relevance to justification"
                                }
                            },
                            "required": ["source"]
                        }
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "justification_id",
            "context",
            "ethical_principles",
            "stakeholder_analysis",
            "reasoning",
            "decision"
        ]
    }
) 