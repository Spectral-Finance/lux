"""
HypothesisFormulation Schema

This schema defines the structure for representing scientific hypothesis formation and testing.
It's particularly useful for:
- Scientific reasoning processes
- Experimental design
- Theory development
- Hypothesis testing and validation

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.cognitive.hypothesis_formulation import HypothesisFormulationSchema

# Create a hypothesis about user behavior
signal = Signal(
    schema=HypothesisFormulationSchema,
    payload={
        "domain": "user_behavior",
        "observation": "Users spend 40% less time on the new dashboard compared to the old one",
        "background_knowledge": [
            "Previous dashboard had 8 widgets",
            "New dashboard has 5 widgets with improved data density",
            "User engagement typically correlates with information accessibility"
        ],
        "hypothesis": {
            "statement": "The reduced time spent is due to improved information density and layout",
            "type": "explanatory",
            "variables": {
                "independent": ["dashboard_layout", "information_density"],
                "dependent": ["time_spent", "task_completion_rate"]
            },
            "predictions": [
                "Users will complete same tasks in less time",
                "Task success rate will remain constant or improve"
            ]
        },
        "alternative_hypotheses": [
            {
                "statement": "Users are spending less time due to missing critical information",
                "evidence_against": [
                    "Task completion rates have not decreased",
                    "User satisfaction scores remain high"
                ]
            }
        ],
        "testing_approach": {
            "methodology": "A/B Test with user tracking",
            "metrics": [
                "Time to complete common tasks",
                "Task success rate",
                "User satisfaction score"
            ],
            "control_variables": [
                "User experience level",
                "Time of day"
            ],
            "sample_size": 1000,
            "duration_days": 14
        },
        "confidence_score": 0.85,
        "supporting_evidence": [
            "Preliminary user feedback",
            "Heatmap analysis of new layout",
            "Similar results in competitor products"
        ],
        "potential_biases": [
            "Confirmation bias in user feedback collection",
            "Selection bias in early adopter group"
        ]
    }
)
```

Schema Structure:
- domain: Field or area of investigation
- observation: The phenomenon being investigated
- background_knowledge: Relevant prior knowledge
- hypothesis: The main hypothesis being formulated
  - statement: Clear statement of the hypothesis
  - type: Type of hypothesis (e.g., explanatory, predictive)
  - variables: Independent and dependent variables
  - predictions: Expected outcomes if hypothesis is true
- alternative_hypotheses: Other possible explanations
- testing_approach: How to test the hypothesis
- confidence_score: Confidence in the hypothesis (0-1)
- supporting_evidence: Evidence supporting the hypothesis
- potential_biases: Possible sources of bias

The schema enforces:
- Required hypothesis components
- Valid confidence scores
- Structured testing approach
- Documentation of potential biases
"""

from lux_sdk.signals import SignalSchema

SCHEMA = {
    "type": "object",
    "properties": {
        "domain": {
            "type": "string",
            "description": "Field or area of investigation"
        },
        "observation": {
            "type": "string",
            "description": "The phenomenon being investigated"
        },
        "background_knowledge": {
            "type": "array",
            "items": {
                "type": "string"
            },
            "description": "Relevant prior knowledge and context"
        },
        "hypothesis": {
            "type": "object",
            "properties": {
                "statement": {
                    "type": "string",
                    "description": "Clear statement of the hypothesis"
                },
                "type": {
                    "type": "string",
                    "enum": ["explanatory", "predictive", "descriptive", "correlational"],
                    "description": "Type of hypothesis"
                },
                "variables": {
                    "type": "object",
                    "properties": {
                        "independent": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Variables being manipulated or studied"
                        },
                        "dependent": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Variables being measured or observed"
                        }
                    },
                    "required": ["independent", "dependent"],
                    "additionalProperties": False
                },
                "predictions": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Expected outcomes if hypothesis is true"
                }
            },
            "required": ["statement", "type", "variables", "predictions"],
            "additionalProperties": False
        },
        "alternative_hypotheses": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "statement": {
                        "type": "string",
                        "description": "Alternative explanation"
                    },
                    "evidence_against": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Evidence that challenges this alternative"
                    }
                },
                "required": ["statement"],
                "additionalProperties": False
            },
            "description": "Other possible explanations"
        },
        "testing_approach": {
            "type": "object",
            "properties": {
                "methodology": {
                    "type": "string",
                    "description": "How the hypothesis will be tested"
                },
                "metrics": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Measurements to be taken"
                },
                "control_variables": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Variables to be controlled"
                },
                "sample_size": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "Number of samples/participants"
                },
                "duration_days": {
                    "type": "number",
                    "minimum": 0,
                    "description": "Duration of testing in days"
                }
            },
            "required": ["methodology", "metrics"],
            "additionalProperties": False
        },
        "confidence_score": {
            "type": "number",
            "minimum": 0,
            "maximum": 1,
            "description": "Confidence in the hypothesis (0-1)"
        },
        "supporting_evidence": {
            "type": "array",
            "items": {"type": "string"},
            "description": "Evidence supporting the hypothesis"
        },
        "potential_biases": {
            "type": "array",
            "items": {"type": "string"},
            "description": "Possible sources of bias in the hypothesis"
        }
    },
    "required": [
        "domain",
        "observation",
        "hypothesis",
        "testing_approach",
        "confidence_score"
    ],
    "additionalProperties": False
}

HypothesisFormulationSchema = SignalSchema(
    name="lux.cognitive.hypothesis_formulation",
    version="1.0",
    description="Schema for representing scientific hypothesis formation and testing",
    schema=SCHEMA
) 