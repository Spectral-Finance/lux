"""
EthicalDilemmaSchema

This schema represents ethical dilemma specifications, including
stakeholders, principles, considerations, and decision frameworks.
"""

from lux_sdk.signals import SignalSchema

EthicalDilemmaSchema = SignalSchema(
    name="ethical_dilemma",
    version="1.0",
    description="Schema for representing ethical dilemma specifications and analysis",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "dilemma_id": {"type": "string", "required": True},
            "title": {"type": "string", "required": True},
            "description": {"type": "string", "required": True},
            "context": {
                "type": "object",
                "required": True,
                "properties": {
                    "background": {"type": "string", "required": True},
                    "domain": {"type": "string", "required": True},
                    "urgency": {"type": "string", "enum": ["immediate", "short_term", "long_term"], "required": True},
                    "scope": {"type": "string", "enum": ["individual", "organizational", "societal"], "required": True}
                }
            },
            "stakeholders": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "group": {"type": "string", "required": True},
                        "interests": {"type": "array", "items": {"type": "string"}, "required": True},
                        "impact_level": {"type": "string", "enum": ["high", "medium", "low"], "required": True},
                        "considerations": {"type": "array", "items": {"type": "string"}, "required": True}
                    }
                }
            },
            "ethical_principles": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "principle": {"type": "string", "required": True},
                        "relevance": {"type": "string", "required": True},
                        "conflicts": {"type": "array", "items": {"type": "string"}},
                        "priority": {"type": "integer", "minimum": 1, "maximum": 5, "required": True}
                    }
                }
            },
            "options": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "description": {"type": "string", "required": True},
                        "consequences": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "stakeholder": {"type": "string", "required": True},
                                    "impact": {"type": "string", "required": True},
                                    "likelihood": {"type": "string", "enum": ["high", "medium", "low"], "required": True},
                                    "timeframe": {"type": "string"}
                                }
                            }
                        },
                        "ethical_implications": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "principle": {"type": "string", "required": True},
                                    "alignment": {"type": "string", "enum": ["supports", "conflicts", "neutral"], "required": True},
                                    "justification": {"type": "string", "required": True}
                                }
                            }
                        }
                    }
                }
            },
            "analysis_framework": {
                "type": "object",
                "required": True,
                "properties": {
                    "approach": {"type": "string", "enum": ["utilitarian", "deontological", "virtue_ethics", "care_ethics", "hybrid"], "required": True},
                    "criteria": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "description": {"type": "string", "required": True},
                                "weight": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True}
                            }
                        }
                    },
                    "considerations": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "factor": {"type": "string", "required": True},
                                "importance": {"type": "string", "enum": ["critical", "important", "relevant"], "required": True},
                                "rationale": {"type": "string", "required": True}
                            }
                        }
                    }
                }
            },
            "recommendations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "option": {"type": "string", "required": True},
                        "rationale": {"type": "string", "required": True},
                        "mitigations": {"type": "array", "items": {"type": "string"}},
                        "monitoring": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "metric": {"type": "string", "required": True},
                                    "threshold": {"type": "string", "required": True},
                                    "frequency": {"type": "string", "required": True}
                                }
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {"type": "string"},
                    "creation_date": {"type": "string", "format": "date-time"},
                    "last_modified": {"type": "string", "format": "date-time"},
                    "status": {"type": "string", "enum": ["draft", "under_review", "resolved", "archived"]},
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "references": {"type": "array", "items": {"type": "string"}},
                    "review_history": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "reviewer": {"type": "string"},
                                "date": {"type": "string", "format": "date-time"},
                                "comments": {"type": "string"}
                            }
                        }
                    }
                }
            }
        }
    }
) 