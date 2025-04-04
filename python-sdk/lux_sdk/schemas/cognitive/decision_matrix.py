"""
DecisionMatrix Schema

This schema defines the structure for representing decision-making processes using a weighted
criteria matrix. It's particularly useful for:
- Multi-criteria decision making
- Option comparison and evaluation
- Transparent decision processes
- Collaborative decision making between agents

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.cognitive.decision_matrix import DecisionMatrixSchema

# Create a decision matrix for choosing a cloud provider
signal = Signal(
    schema=DecisionMatrixSchema,
    payload={
        "decision_context": "Selecting cloud provider for ML infrastructure",
        "criteria": [
            {
                "name": "Cost",
                "weight": 0.3,
                "description": "Monthly operational costs",
                "evaluation_method": "Lower is better",
                "unit": "USD/month"
            },
            {
                "name": "Performance",
                "weight": 0.25,
                "description": "GPU compute performance",
                "evaluation_method": "Higher is better",
                "unit": "TFLOPS"
            },
            {
                "name": "Reliability",
                "weight": 0.25,
                "description": "Historical uptime",
                "evaluation_method": "Higher is better",
                "unit": "percentage"
            },
            {
                "name": "Integration Ease",
                "weight": 0.2,
                "description": "Ease of integration with existing systems",
                "evaluation_method": "Higher is better",
                "unit": "score"
            }
        ],
        "options": [
            {
                "name": "AWS",
                "scores": [
                    {"criterion": "Cost", "value": 8.5, "notes": "Based on reserved instances"},
                    {"criterion": "Performance", "value": 9.0, "notes": "Latest GPU instances"},
                    {"criterion": "Reliability", "value": 9.5, "notes": "99.99% SLA"},
                    {"criterion": "Integration Ease", "value": 8.0, "notes": "Good SDK support"}
                ]
            },
            {
                "name": "GCP",
                "scores": [
                    {"criterion": "Cost", "value": 9.0, "notes": "Competitive pricing"},
                    {"criterion": "Performance", "value": 8.5, "notes": "Strong but slightly behind"},
                    {"criterion": "Reliability", "value": 9.0, "notes": "99.95% SLA"},
                    {"criterion": "Integration Ease", "value": 8.5, "notes": "Excellent documentation"}
                ]
            }
        ],
        "constraints": [
            {
                "description": "Must support region: US-East",
                "is_satisfied": true
            },
            {
                "description": "Must provide GPU instances",
                "is_satisfied": true
            }
        ],
        "final_scores": [
            {"option": "AWS", "score": 8.825},
            {"option": "GCP", "score": 8.75}
        ],
        "selected_option": "AWS",
        "justification": "AWS selected due to slightly better overall score, particularly in performance and reliability metrics",
        "confidence_score": 0.85
    }
)
```

Schema Structure:
- decision_context: Description of the decision to be made
- criteria: Array of evaluation criteria, each with:
  - name: Criterion identifier
  - weight: Importance weight (0-1)
  - description: Detailed explanation
  - evaluation_method: How to evaluate this criterion
  - unit: Unit of measurement
- options: Array of alternatives to evaluate, each with:
  - name: Option identifier
  - scores: Array of scores for each criterion
- constraints: Array of must-have requirements
- final_scores: Weighted scores for each option
- selected_option: The chosen alternative
- justification: Explanation of the decision
- confidence_score: Confidence in the decision (0-1)

The schema enforces:
- Weights sum to 1.0
- Valid score ranges
- Consistent criteria across options
- Required justification for decisions
"""

from lux_sdk.signals import SignalSchema

SCHEMA = {
    "type": "object",
    "properties": {
        "decision_context": {
            "type": "string",
            "description": "Description of the decision to be made"
        },
        "criteria": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Criterion identifier"
                    },
                    "weight": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Importance weight (0-1)"
                    },
                    "description": {
                        "type": "string",
                        "description": "Detailed explanation of the criterion"
                    },
                    "evaluation_method": {
                        "type": "string",
                        "description": "How to evaluate this criterion"
                    },
                    "unit": {
                        "type": "string",
                        "description": "Unit of measurement"
                    }
                },
                "required": ["name", "weight", "description", "evaluation_method"],
                "additionalProperties": False
            },
            "minItems": 1,
            "description": "Array of evaluation criteria"
        },
        "options": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Option identifier"
                    },
                    "scores": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "criterion": {
                                    "type": "string",
                                    "description": "Name of the criterion being scored"
                                },
                                "value": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 10,
                                    "description": "Score value (0-10)"
                                },
                                "notes": {
                                    "type": "string",
                                    "description": "Additional notes about the score"
                                }
                            },
                            "required": ["criterion", "value"],
                            "additionalProperties": False
                        }
                    }
                },
                "required": ["name", "scores"],
                "additionalProperties": False
            },
            "minItems": 2,
            "description": "Array of alternatives to evaluate"
        },
        "constraints": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "description": {
                        "type": "string",
                        "description": "Description of the constraint"
                    },
                    "is_satisfied": {
                        "type": "boolean",
                        "description": "Whether the constraint is satisfied"
                    }
                },
                "required": ["description", "is_satisfied"],
                "additionalProperties": False
            },
            "description": "Array of must-have requirements"
        },
        "final_scores": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "option": {
                        "type": "string",
                        "description": "Name of the option"
                    },
                    "score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10,
                        "description": "Final weighted score"
                    }
                },
                "required": ["option", "score"],
                "additionalProperties": False
            },
            "description": "Final weighted scores for each option"
        },
        "selected_option": {
            "type": "string",
            "description": "The chosen alternative"
        },
        "justification": {
            "type": "string",
            "description": "Explanation of why this option was selected"
        },
        "confidence_score": {
            "type": "number",
            "minimum": 0,
            "maximum": 1,
            "description": "Confidence in the decision (0-1)"
        }
    },
    "required": [
        "decision_context",
        "criteria",
        "options",
        "final_scores",
        "selected_option",
        "justification",
        "confidence_score"
    ],
    "additionalProperties": False
}

DecisionMatrixSchema = SignalSchema(
    name="lux.cognitive.decision_matrix",
    version="1.0",
    description="Schema for representing decision matrices and their outcomes",
    schema=SCHEMA
) 