"""
BeliefUpdate Schema

This schema defines the structure for representing belief updates and revisions.
It's particularly useful for:
- Belief revision processes
- Evidence-based updates
- Confidence adjustments
- Prior belief tracking
- Belief conflict resolution

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.cognitive.belief_update import BeliefUpdateSchema

# Create a belief update about market trends
signal = Signal(
    schema=BeliefUpdateSchema,
    payload={
        "context": {
            "domain": "market_analysis",
            "timestamp": "2024-03-15T14:30:00Z",
            "update_trigger": "new_market_data",
            "urgency": 0.8
        },
        "prior_belief": {
            "statement": "Market growth will continue at 5% annually",
            "confidence": 0.75,
            "supporting_evidence": [
                "Historical growth patterns",
                "Industry analyst predictions",
                "Consumer confidence indices"
            ],
            "assumptions": [
                "Stable economic conditions",
                "No major market disruptions"
            ],
            "formation_date": "2024-01-15T00:00:00Z"
        },
        "new_evidence": {
            "sources": [
                {
                    "type": "market_data",
                    "content": "Q1 growth at 2.5%",
                    "reliability": 0.9,
                    "timestamp": "2024-03-15T10:00:00Z"
                },
                {
                    "type": "expert_analysis",
                    "content": "Market headwinds increasing",
                    "reliability": 0.85,
                    "timestamp": "2024-03-14T16:00:00Z"
                }
            ],
            "contradictions": [
                {
                    "aspect": "growth_rate",
                    "prior_value": "5% growth",
                    "new_value": "2.5% growth",
                    "significance": 0.8
                }
            ],
            "supporting_factors": [
                {
                    "factor": "economic_indicators",
                    "impact": "moderate_negative",
                    "confidence": 0.75
                }
            ]
        },
        "update_process": {
            "method": "bayesian_update",
            "steps": [
                {
                    "action": "evidence_evaluation",
                    "description": "Assessed reliability of new data",
                    "outcome": "High confidence in market data"
                },
                {
                    "action": "contradiction_analysis",
                    "description": "Evaluated conflicts with prior belief",
                    "outcome": "Significant deviation in growth projections"
                },
                {
                    "action": "belief_revision",
                    "description": "Updated growth expectations",
                    "outcome": "Reduced growth projection"
                }
            ],
            "reasoning": [
                "New data shows consistent trend",
                "Multiple reliable sources confirm slowdown",
                "Economic indicators align with new projection"
            ]
        },
        "updated_belief": {
            "statement": "Market growth will slow to 2-3% annually",
            "confidence": 0.85,
            "key_changes": [
                {
                    "aspect": "growth_rate",
                    "from_value": "5%",
                    "to_value": "2-3%",
                    "confidence_delta": 0.1
                }
            ],
            "supporting_evidence": [
                "Q1 market performance",
                "Expert analysis reports",
                "Economic indicator trends"
            ],
            "implications": [
                {
                    "area": "investment_strategy",
                    "impact": "Adjust portfolio allocation",
                    "urgency": 0.7
                },
                {
                    "area": "risk_assessment",
                    "impact": "Increase risk monitoring",
                    "urgency": 0.8
                }
            ]
        },
        "uncertainty_assessment": {
            "known_unknowns": [
                "Long-term economic policy impacts",
                "Competitor responses to slowdown"
            ],
            "confidence_factors": {
                "data_quality": 0.9,
                "source_reliability": 0.85,
                "analysis_rigor": 0.8
            },
            "potential_biases": [
                {
                    "type": "recency_bias",
                    "description": "Over-emphasis on recent data",
                    "mitigation": "Considered longer-term trends"
                }
            ]
        },
        "metadata": {
            "update_id": "BU_2024_03_15_001",
            "related_updates": ["BU_2024_01_15_003"],
            "tags": ["market_analysis", "growth_projection", "economic_trends"]
        }
    }
)
```

Schema Structure:
- context: Update situation and timing
- prior_belief: Original belief state
- new_evidence: Information causing update
- update_process: How belief was updated
- updated_belief: New belief state
- uncertainty_assessment: Confidence and unknowns
- metadata: Additional information

The schema enforces:
- Valid confidence scores
- Required evidence components
- Temporal consistency
- Process documentation
- Uncertainty tracking
"""

from lux_sdk.signals import SignalSchema

SCHEMA = {
    "type": "object",
    "properties": {
        "context": {
            "type": "object",
            "properties": {
                "domain": {
                    "type": "string",
                    "description": "Area of belief"
                },
                "timestamp": {
                    "type": "string",
                    "format": "date-time",
                    "description": "When update occurred"
                },
                "update_trigger": {
                    "type": "string",
                    "description": "What prompted the update"
                },
                "urgency": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Update urgency"
                }
            },
            "required": ["domain", "timestamp", "update_trigger"],
            "additionalProperties": False
        },
        "prior_belief": {
            "type": "object",
            "properties": {
                "statement": {
                    "type": "string",
                    "description": "Original belief"
                },
                "confidence": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Confidence in prior belief"
                },
                "supporting_evidence": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Evidence for prior belief"
                },
                "assumptions": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Underlying assumptions"
                },
                "formation_date": {
                    "type": "string",
                    "format": "date-time",
                    "description": "When belief was formed"
                }
            },
            "required": ["statement", "confidence"],
            "additionalProperties": False
        },
        "new_evidence": {
            "type": "object",
            "properties": {
                "sources": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "type": {
                                "type": "string",
                                "description": "Type of evidence"
                            },
                            "content": {
                                "type": "string",
                                "description": "Evidence content"
                            },
                            "reliability": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Source reliability"
                            },
                            "timestamp": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When evidence was received"
                            }
                        },
                        "required": ["type", "content", "reliability"],
                        "additionalProperties": False
                    }
                },
                "contradictions": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "aspect": {
                                "type": "string",
                                "description": "What is contradicted"
                            },
                            "prior_value": {
                                "type": "string",
                                "description": "Original value"
                            },
                            "new_value": {
                                "type": "string",
                                "description": "Contradicting value"
                            },
                            "significance": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Importance of contradiction"
                            }
                        },
                        "required": ["aspect", "prior_value", "new_value"],
                        "additionalProperties": False
                    }
                },
                "supporting_factors": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "factor": {
                                "type": "string",
                                "description": "Supporting element"
                            },
                            "impact": {
                                "type": "string",
                                "description": "Effect on belief"
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Confidence in factor"
                            }
                        },
                        "required": ["factor", "impact"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["sources"],
            "additionalProperties": False
        },
        "update_process": {
            "type": "object",
            "properties": {
                "method": {
                    "type": "string",
                    "description": "Update methodology"
                },
                "steps": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "action": {
                                "type": "string",
                                "description": "Step taken"
                            },
                            "description": {
                                "type": "string",
                                "description": "Step details"
                            },
                            "outcome": {
                                "type": "string",
                                "description": "Step result"
                            }
                        },
                        "required": ["action", "description"],
                        "additionalProperties": False
                    }
                },
                "reasoning": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Update rationale"
                }
            },
            "required": ["method", "steps"],
            "additionalProperties": False
        },
        "updated_belief": {
            "type": "object",
            "properties": {
                "statement": {
                    "type": "string",
                    "description": "New belief"
                },
                "confidence": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Confidence in new belief"
                },
                "key_changes": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "aspect": {
                                "type": "string",
                                "description": "What changed"
                            },
                            "from_value": {
                                "type": "string",
                                "description": "Original value"
                            },
                            "to_value": {
                                "type": "string",
                                "description": "New value"
                            },
                            "confidence_delta": {
                                "type": "number",
                                "minimum": -1,
                                "maximum": 1,
                                "description": "Change in confidence"
                            }
                        },
                        "required": ["aspect", "from_value", "to_value"],
                        "additionalProperties": False
                    }
                },
                "supporting_evidence": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Evidence for new belief"
                },
                "implications": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "area": {
                                "type": "string",
                                "description": "Affected area"
                            },
                            "impact": {
                                "type": "string",
                                "description": "Effect of change"
                            },
                            "urgency": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Action urgency"
                            }
                        },
                        "required": ["area", "impact"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["statement", "confidence"],
            "additionalProperties": False
        },
        "uncertainty_assessment": {
            "type": "object",
            "properties": {
                "known_unknowns": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Recognized uncertainties"
                },
                "confidence_factors": {
                    "type": "object",
                    "properties": {
                        "data_quality": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Quality of data"
                        },
                        "source_reliability": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Reliability of sources"
                        },
                        "analysis_rigor": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Thoroughness of analysis"
                        }
                    },
                    "additionalProperties": False
                },
                "potential_biases": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "type": {
                                "type": "string",
                                "description": "Type of bias"
                            },
                            "description": {
                                "type": "string",
                                "description": "Bias details"
                            },
                            "mitigation": {
                                "type": "string",
                                "description": "How bias was addressed"
                            }
                        },
                        "required": ["type", "description"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["known_unknowns"],
            "additionalProperties": False
        },
        "metadata": {
            "type": "object",
            "properties": {
                "update_id": {
                    "type": "string",
                    "description": "Unique update identifier"
                },
                "related_updates": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Related belief updates"
                },
                "tags": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Categorization tags"
                }
            },
            "required": ["update_id"],
            "additionalProperties": False
        }
    },
    "required": [
        "context",
        "prior_belief",
        "new_evidence",
        "update_process",
        "updated_belief"
    ],
    "additionalProperties": False
}

BeliefUpdateSchema = SignalSchema(
    name="lux.cognitive.belief_update",
    version="1.0",
    description="Schema for representing belief updates and revisions",
    schema=SCHEMA
) 