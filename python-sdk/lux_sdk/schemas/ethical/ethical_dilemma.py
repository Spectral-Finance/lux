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
            "timestamp": {"type": "string", "format": "date-time"},
            "dilemma_id": {"type": "string"},
            "title": {"type": "string"},
            "description": {"type": "string"},
            "context": {
                "type": "object",
                "properties": {
                    "background": {"type": "string"},
                    "domain": {"type": "string"},
                    "urgency": {"type": "string", "enum": ["immediate", "short_term", "long_term"]},
                    "scope": {"type": "string", "enum": ["individual", "organizational", "societal"]}
                },
                "required": ["background", "domain", "urgency", "scope"]
            },
            "stakeholders": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "group": {"type": "string"},
                        "interests": {"type": "array", "items": {"type": "string"}},
                        "impact_level": {"type": "string", "enum": ["high", "medium", "low"]},
                        "considerations": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["group", "interests", "impact_level", "considerations"]
                }
            },
            "ethical_principles": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "principle": {"type": "string"},
                        "relevance": {"type": "string"},
                        "conflicts": {"type": "array", "items": {"type": "string"}},
                        "priority": {"type": "integer", "minimum": 1, "maximum": 5}
                    },
                    "required": ["principle", "relevance", "priority"]
                }
            },
            "options": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "description": {"type": "string"},
                        "consequences": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "stakeholder": {"type": "string"},
                                    "impact": {"type": "string"},
                                    "likelihood": {"type": "string", "enum": ["high", "medium", "low"]},
                                    "timeframe": {"type": "string"}
                                },
                                "required": ["stakeholder", "impact", "likelihood"]
                            }
                        },
                        "ethical_implications": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "principle": {"type": "string"},
                                    "alignment": {"type": "string", "enum": ["supports", "conflicts", "neutral"]},
                                    "justification": {"type": "string"}
                                },
                                "required": ["principle", "alignment", "justification"]
                            }
                        }
                    },
                    "required": ["description"]
                }
            },
            "analysis_framework": {
                "type": "object",
                "properties": {
                    "approach": {"type": "string", "enum": ["utilitarian", "deontological", "virtue_ethics", "care_ethics", "hybrid"]},
                    "criteria": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "description": {"type": "string"},
                                "weight": {"type": "number", "minimum": 0.0, "maximum": 1.0}
                            },
                            "required": ["name", "description", "weight"]
                        }
                    },
                    "considerations": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "factor": {"type": "string"},
                                "importance": {"type": "string", "enum": ["critical", "important", "relevant"]},
                                "rationale": {"type": "string"}
                            },
                            "required": ["factor", "importance", "rationale"]
                        }
                    }
                },
                "required": ["approach"]
            },
            "recommendations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "option": {"type": "string"},
                        "rationale": {"type": "string"},
                        "mitigations": {"type": "array", "items": {"type": "string"}},
                        "monitoring": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "metric": {"type": "string"},
                                    "threshold": {"type": "string"},
                                    "frequency": {"type": "string"}
                                },
                                "required": ["metric", "threshold", "frequency"]
                            }
                        }
                    },
                    "required": ["option", "rationale"]
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
        },
        "required": ["timestamp", "dilemma_id", "title", "description", "context", "stakeholders", "ethical_principles", "options", "analysis_framework"]
    }
) 