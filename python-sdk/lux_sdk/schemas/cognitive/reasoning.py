"""
Reasoning Schema

This schema defines the structure for representing reasoning processes,
including deductive, inductive, and abductive reasoning steps, logical operations,
and inference chains.

Example:
{
    "timestamp": "2024-04-03T12:34:56Z",
    "reasoning_id": "reason-123",
    "reasoning_type": "deductive",
    "context": {
        "domain": "medical_diagnosis",
        "confidence_threshold": 0.8,
        "time_constraints": "real-time"
    },
    "premises": [
        {
            "statement": "All patients with symptom X have condition Y",
            "confidence": 0.95,
            "source": "medical_knowledge_base"
        },
        {
            "statement": "Patient shows symptom X",
            "confidence": 0.9,
            "source": "clinical_observation"
        }
    ],
    "logical_operations": [
        {
            "operation_type": "modus_ponens",
            "inputs": ["premise_1", "premise_2"],
            "output": "conclusion_1"
        }
    ],
    "conclusions": [
        {
            "id": "conclusion_1",
            "statement": "Patient likely has condition Y",
            "confidence": 0.85,
            "supporting_evidence": ["premise_1", "premise_2"],
            "uncertainty_factors": ["measurement_error", "symptom_ambiguity"]
        }
    ],
    "metadata": {
        "reasoning_duration": 0.5,
        "validation_method": "expert_review",
        "revision_history": []
    }
}
"""

from lux_sdk.signals import SignalSchema

ReasoningSchema = SignalSchema(
    name="reasoning",
    version="1.0",
    description="Schema for representing reasoning processes and logical operations",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "When the reasoning process occurred"
            },
            "reasoning_id": {
                "type": "string",
                "description": "Unique identifier for the reasoning process"
            },
            "reasoning_type": {
                "type": "string",
                "enum": ["deductive", "inductive", "abductive", "analogical", "causal"],
                "description": "The type of reasoning being employed"
            },
            "context": {
                "type": "object",
                "properties": {
                    "domain": {
                        "type": "string",
                        "description": "Domain or field of reasoning"
                    },
                    "confidence_threshold": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Minimum confidence level required"
                    },
                    "time_constraints": {
                        "type": "string",
                        "description": "Time constraints for the reasoning process"
                    }
                },
                "required": ["domain", "confidence_threshold"]
            },
            "premises": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "statement": {
                            "type": "string",
                            "description": "The premise statement"
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Confidence in the premise"
                        },
                        "source": {
                            "type": "string",
                            "description": "Source of the premise"
                        }
                    },
                    "required": ["statement", "confidence"]
                },
                "minItems": 1,
                "description": "List of premises used in reasoning"
            },
            "logical_operations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "operation_type": {
                            "type": "string",
                            "description": "Type of logical operation"
                        },
                        "inputs": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Input references for the operation"
                        },
                        "output": {
                            "type": "string",
                            "description": "Output reference from the operation"
                        }
                    },
                    "required": ["operation_type", "inputs", "output"]
                },
                "description": "Sequence of logical operations performed"
            },
            "conclusions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": "Unique identifier for the conclusion"
                        },
                        "statement": {
                            "type": "string",
                            "description": "The conclusion statement"
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Confidence in the conclusion"
                        },
                        "supporting_evidence": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "References to supporting evidence"
                        },
                        "uncertainty_factors": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Factors contributing to uncertainty"
                        }
                    },
                    "required": ["id", "statement", "confidence"]
                },
                "minItems": 1,
                "description": "List of conclusions derived from reasoning"
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "reasoning_duration": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Duration of reasoning process in seconds"
                    },
                    "validation_method": {
                        "type": "string",
                        "description": "Method used to validate reasoning"
                    },
                    "revision_history": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "timestamp": {"type": "string", "format": "date-time"},
                                "change": {"type": "string"},
                                "reason": {"type": "string"}
                            }
                        },
                        "description": "History of revisions to the reasoning"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "reasoning_id",
            "reasoning_type",
            "context",
            "premises",
            "conclusions"
        ]
    }
) 