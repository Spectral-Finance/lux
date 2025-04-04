"""
Schema for representing ethical decision-making and moral judgments.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class MoralJudgmentSchema(SignalSchema):
    """Schema for representing ethical decision-making and moral judgments.
    
    This schema defines the structure for documenting and analyzing moral judgments,
    ethical decisions, and their underlying reasoning and implications.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "judgment_id": "mj_20240403_153000",
            "context_id": "ctx_789",
            "ethical_context": {
                "situation": "AI system deployment impact on privacy",
                "stakeholders": [{
                    "id": "users",
                    "role": "data_subjects",
                    "interests": [
                        "privacy protection",
                        "service quality"
                    ],
                    "impact_level": "high"
                }],
                "domain": "ai_ethics",
                "timeframe": {
                    "immediate": "User data collection",
                    "short_term": "Service personalization",
                    "long_term": "Privacy implications"
                }
            },
            "ethical_principles": [{
                "principle": "privacy",
                "description": "Respect for personal data and privacy",
                "relevance": "direct",
                "weight": 0.9,
                "conflicts": ["service_quality"]
            }],
            "analysis": {
                "facts": [{
                    "statement": "System requires personal data",
                    "certainty": 1.0,
                    "source": "technical_specs"
                }],
                "assumptions": [{
                    "assumption": "Data minimization possible",
                    "justification": "Technical analysis",
                    "impact": "Affects privacy protection"
                }],
                "considerations": [{
                    "aspect": "data_collection",
                    "analysis": "Minimum necessary data",
                    "implications": [
                        "Reduced privacy risk",
                        "Limited functionality"
                    ]
                }]
            },
            "alternatives": [{
                "action": "Implement strict data minimization",
                "rationale": "Prioritize privacy protection",
                "consequences": [{
                    "outcome": "Enhanced privacy",
                    "probability": 0.9,
                    "impact": "Positive for user trust"
                }],
                "ethical_alignment": {
                    "score": 0.85,
                    "breakdown": [{
                        "principle": "privacy",
                        "alignment": 0.9,
                        "explanation": "Strong privacy protection"
                    }]
                }
            }],
            "judgment": {
                "decision": "Implement data minimization with opt-in features",
                "justification": "Balance privacy and functionality",
                "confidence": 0.85,
                "trade_offs": [{
                    "description": "Reduced personalization vs privacy",
                    "resolution": "User-controlled features"
                }],
                "mitigations": [{
                    "risk": "Data exposure",
                    "measure": "Encryption",
                    "effectiveness": 0.95
                }]
            },
            "review_process": {
                "reviewers": [{
                    "id": "ethics_board_1",
                    "role": "privacy_expert",
                    "assessment": "Approved with recommendations",
                    "concerns": ["Long-term data retention"]
                }],
                "consensus": {
                    "level": 0.9,
                    "points_of_agreement": [
                        "Data minimization approach",
                        "User control"
                    ],
                    "points_of_contention": [
                        "Retention period"
                    ]
                }
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "ethics_officer",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "reviewed",
                "framework": "privacy_first",
                "references": [
                    "GDPR guidelines",
                    "Ethics handbook"
                ],
                "tags": [
                    "privacy",
                    "ai_ethics",
                    "data_protection"
                ]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="moral_judgment",
            version="1.0",
            description="Schema for representing ethical decision-making and moral judgments",
            schema={
                "type": "object",
                "required": ["timestamp", "judgment_id", "context_id", "ethical_context", "ethical_principles", "analysis", "judgment"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the moral judgment"
                    },
                    "judgment_id": {
                        "type": "string",
                        "description": "Unique identifier for the moral judgment"
                    },
                    "context_id": {
                        "type": "string",
                        "description": "Identifier of the ethical context or situation"
                    },
                    "ethical_context": {
                        "type": "object",
                        "description": "Context of the ethical decision",
                        "required": ["situation", "stakeholders"],
                        "properties": {
                            "situation": {
                                "type": "string",
                                "description": "Description of the ethical situation"
                            },
                            "stakeholders": {
                                "type": "array",
                                "description": "Affected parties",
                                "items": {
                                    "type": "object",
                                    "required": ["id", "role"],
                                    "properties": {
                                        "id": {
                                            "type": "string",
                                            "description": "Stakeholder identifier"
                                        },
                                        "role": {
                                            "type": "string",
                                            "description": "Role in the situation"
                                        },
                                        "interests": {
                                            "type": "array",
                                            "description": "Stakeholder interests",
                                            "items": {"type": "string"}
                                        },
                                        "impact_level": {
                                            "type": "string",
                                            "enum": ["low", "medium", "high"],
                                            "description": "Level of impact on stakeholder"
                                        }
                                    }
                                }
                            },
                            "domain": {
                                "type": "string",
                                "description": "Ethical domain or field"
                            },
                            "timeframe": {
                                "type": "object",
                                "description": "Temporal context",
                                "properties": {
                                    "immediate": {
                                        "type": "string",
                                        "description": "Immediate implications"
                                    },
                                    "short_term": {
                                        "type": "string",
                                        "description": "Short-term considerations"
                                    },
                                    "long_term": {
                                        "type": "string",
                                        "description": "Long-term implications"
                                    }
                                }
                            }
                        }
                    },
                    "ethical_principles": {
                        "type": "array",
                        "description": "Relevant ethical principles",
                        "items": {
                            "type": "object",
                            "required": ["principle", "description"],
                            "properties": {
                                "principle": {
                                    "type": "string",
                                    "description": "Ethical principle name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Principle description"
                                },
                                "relevance": {
                                    "type": "string",
                                    "enum": ["direct", "indirect", "peripheral"],
                                    "description": "Relevance to situation"
                                },
                                "weight": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Relative importance (0-1)"
                                },
                                "conflicts": {
                                    "type": "array",
                                    "description": "Conflicting principles",
                                    "items": {"type": "string"}
                                }
                            }
                        }
                    },
                    "analysis": {
                        "type": "object",
                        "description": "Ethical analysis",
                        "required": ["facts", "assumptions", "considerations"],
                        "properties": {
                            "facts": {
                                "type": "array",
                                "description": "Relevant facts",
                                "items": {
                                    "type": "object",
                                    "required": ["statement"],
                                    "properties": {
                                        "statement": {
                                            "type": "string",
                                            "description": "Factual statement"
                                        },
                                        "certainty": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 1,
                                            "description": "Certainty level (0-1)"
                                        },
                                        "source": {
                                            "type": "string",
                                            "description": "Source of information"
                                        }
                                    }
                                }
                            },
                            "assumptions": {
                                "type": "array",
                                "description": "Key assumptions",
                                "items": {
                                    "type": "object",
                                    "required": ["assumption"],
                                    "properties": {
                                        "assumption": {
                                            "type": "string",
                                            "description": "Assumed condition"
                                        },
                                        "justification": {
                                            "type": "string",
                                            "description": "Justification for assumption"
                                        },
                                        "impact": {
                                            "type": "string",
                                            "description": "Impact on judgment"
                                        }
                                    }
                                }
                            },
                            "considerations": {
                                "type": "array",
                                "description": "Ethical considerations",
                                "items": {
                                    "type": "object",
                                    "required": ["aspect", "analysis"],
                                    "properties": {
                                        "aspect": {
                                            "type": "string",
                                            "description": "Ethical aspect"
                                        },
                                        "analysis": {
                                            "type": "string",
                                            "description": "Analysis of aspect"
                                        },
                                        "implications": {
                                            "type": "array",
                                            "description": "Implications",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "alternatives": {
                        "type": "array",
                        "description": "Alternative courses of action",
                        "items": {
                            "type": "object",
                            "required": ["action", "rationale"],
                            "properties": {
                                "action": {
                                    "type": "string",
                                    "description": "Proposed action"
                                },
                                "rationale": {
                                    "type": "string",
                                    "description": "Reasoning behind action"
                                },
                                "consequences": {
                                    "type": "array",
                                    "description": "Expected consequences",
                                    "items": {
                                        "type": "object",
                                        "required": ["outcome"],
                                        "properties": {
                                            "outcome": {
                                                "type": "string",
                                                "description": "Potential outcome"
                                            },
                                            "probability": {
                                                "type": "number",
                                                "minimum": 0,
                                                "maximum": 1,
                                                "description": "Probability (0-1)"
                                            },
                                            "impact": {
                                                "type": "string",
                                                "description": "Impact description"
                                            }
                                        }
                                    }
                                },
                                "ethical_alignment": {
                                    "type": "object",
                                    "description": "Alignment with principles",
                                    "properties": {
                                        "score": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 1,
                                            "description": "Overall alignment score (0-1)"
                                        },
                                        "breakdown": {
                                            "type": "array",
                                            "description": "Principle-wise alignment",
                                            "items": {
                                                "type": "object",
                                                "required": ["principle", "alignment"],
                                                "properties": {
                                                    "principle": {
                                                        "type": "string",
                                                        "description": "Ethical principle"
                                                    },
                                                    "alignment": {
                                                        "type": "number",
                                                        "minimum": 0,
                                                        "maximum": 1,
                                                        "description": "Alignment score (0-1)"
                                                    },
                                                    "explanation": {
                                                        "type": "string",
                                                        "description": "Alignment explanation"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "judgment": {
                        "type": "object",
                        "description": "Final moral judgment",
                        "required": ["decision", "justification", "confidence"],
                        "properties": {
                            "decision": {
                                "type": "string",
                                "description": "Chosen course of action"
                            },
                            "justification": {
                                "type": "string",
                                "description": "Ethical justification"
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Confidence level (0-1)"
                            },
                            "trade_offs": {
                                "type": "array",
                                "description": "Ethical trade-offs",
                                "items": {
                                    "type": "object",
                                    "required": ["description", "resolution"],
                                    "properties": {
                                        "description": {
                                            "type": "string",
                                            "description": "Trade-off description"
                                        },
                                        "resolution": {
                                            "type": "string",
                                            "description": "How trade-off was resolved"
                                        }
                                    }
                                }
                            },
                            "mitigations": {
                                "type": "array",
                                "description": "Risk mitigation measures",
                                "items": {
                                    "type": "object",
                                    "required": ["risk", "measure"],
                                    "properties": {
                                        "risk": {
                                            "type": "string",
                                            "description": "Ethical risk"
                                        },
                                        "measure": {
                                            "type": "string",
                                            "description": "Mitigation measure"
                                        },
                                        "effectiveness": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 1,
                                            "description": "Expected effectiveness (0-1)"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "review_process": {
                        "type": "object",
                        "description": "Ethical review process",
                        "properties": {
                            "reviewers": {
                                "type": "array",
                                "description": "Ethics reviewers",
                                "items": {
                                    "type": "object",
                                    "required": ["id", "role", "assessment"],
                                    "properties": {
                                        "id": {
                                            "type": "string",
                                            "description": "Reviewer identifier"
                                        },
                                        "role": {
                                            "type": "string",
                                            "description": "Reviewer role"
                                        },
                                        "assessment": {
                                            "type": "string",
                                            "description": "Reviewer's assessment"
                                        },
                                        "concerns": {
                                            "type": "array",
                                            "description": "Raised concerns",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            },
                            "consensus": {
                                "type": "object",
                                "description": "Review consensus",
                                "properties": {
                                    "level": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Consensus level (0-1)"
                                    },
                                    "points_of_agreement": {
                                        "type": "array",
                                        "description": "Agreed points",
                                        "items": {"type": "string"}
                                    },
                                    "points_of_contention": {
                                        "type": "array",
                                        "description": "Disputed points",
                                        "items": {"type": "string"}
                                    }
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the judgment",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Judgment creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Judgment version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "reviewed", "final"],
                                "description": "Status"
                            },
                            "framework": {
                                "type": "string",
                                "description": "Ethical framework used"
                            },
                            "references": {
                                "type": "array",
                                "description": "Reference materials",
                                "items": {"type": "string"}
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