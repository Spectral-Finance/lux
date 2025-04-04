"""
ReasoningChain Schema

This schema defines the structure for representing a chain of reasoning steps that an agent follows
to reach a conclusion. It's particularly useful for:
- Explaining decision-making processes
- Debugging agent reasoning
- Auditing logical steps
- Teaching other agents through example

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.cognitive.reasoning_chain import ReasoningChainSchema

# Create a reasoning chain
signal = Signal(
    schema=ReasoningChainSchema,
    payload={
        "context": "Deciding whether to approve a loan application",
        "steps": [
            {
                "step_id": 1,
                "description": "Check credit score",
                "observation": "Credit score is 750",
                "reasoning": "A credit score above 700 indicates good creditworthiness",
                "confidence": 0.9
            },
            {
                "step_id": 2,
                "description": "Analyze debt-to-income ratio",
                "observation": "Debt-to-income ratio is 25%",
                "reasoning": "Ratio below 30% suggests manageable debt load",
                "confidence": 0.85
            }
        ],
        "conclusion": "Loan application meets initial criteria for approval",
        "confidence_score": 0.87,
        "supporting_evidence": ["High credit score", "Low debt ratio"],
        "assumptions": ["Current employment status will remain stable"]
    }
)
```

Schema Structure:
- context: The situation or problem being reasoned about
- steps: Array of reasoning steps, each with:
  - step_id: Unique identifier for the step
  - description: What is being evaluated
  - observation: Relevant facts or data
  - reasoning: Logic applied to the observation
  - confidence: Confidence in this step (0-1)
- conclusion: Final outcome of the reasoning chain
- confidence_score: Overall confidence in the conclusion (0-1)
- supporting_evidence: List of key points supporting the conclusion
- assumptions: List of assumptions made during reasoning

The schema enforces:
- Sequential step_ids
- Valid confidence scores
- Required fields at each step
- Logical flow from context through steps to conclusion
"""

from lux_sdk.signals import SignalSchema

SCHEMA = {
    "type": "object",
    "properties": {
        "context": {
            "type": "string",
            "description": "The situation or problem being reasoned about"
        },
        "steps": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "step_id": {
                        "type": "integer",
                        "minimum": 1,
                        "description": "Sequential identifier for the reasoning step"
                    },
                    "description": {
                        "type": "string",
                        "description": "What is being evaluated in this step"
                    },
                    "observation": {
                        "type": "string",
                        "description": "Relevant facts or data for this step"
                    },
                    "reasoning": {
                        "type": "string",
                        "description": "Logic applied to the observation"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence score for this step (0-1)"
                    }
                },
                "required": ["step_id", "description", "observation", "reasoning", "confidence"],
                "additionalProperties": False
            },
            "minItems": 1,
            "description": "Sequential steps in the reasoning process"
        },
        "conclusion": {
            "type": "string",
            "description": "Final outcome of the reasoning chain"
        },
        "confidence_score": {
            "type": "number",
            "minimum": 0,
            "maximum": 1,
            "description": "Overall confidence in the conclusion (0-1)"
        },
        "supporting_evidence": {
            "type": "array",
            "items": {
                "type": "string"
            },
            "description": "List of key points supporting the conclusion"
        },
        "assumptions": {
            "type": "array",
            "items": {
                "type": "string"
            },
            "description": "List of assumptions made during reasoning"
        }
    },
    "required": ["context", "steps", "conclusion", "confidence_score"],
    "additionalProperties": False
}

ReasoningChainSchema = SignalSchema(
    name="lux.cognitive.reasoning_chain",
    version="1.0",
    description="Schema for representing chains of reasoning steps and conclusions",
    schema=SCHEMA
) 