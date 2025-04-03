"""
ProblemDecompositionSchema

This schema represents the decomposition of complex problems into simpler subproblems,
including their relationships, dependencies, and solution strategies.
"""

from lux_sdk.signals import SignalSchema

ProblemDecompositionSchema = SignalSchema(
    name="problem_decomposition",
    version="1.0",
    description="Schema for representing problem decomposition in cognitive processes",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time"},
            "decomposition_id": {"type": "string"},
            "original_problem": {
                "type": "object",
                "properties": {
                    "problem_id": {"type": "string"},
                    "description": {"type": "string"},
                    "complexity_level": {"type": "integer", "minimum": 1, "maximum": 10}
                },
                "required": ["problem_id", "description"]
            },
            "subproblems": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "subproblem_id": {"type": "string"},
                        "description": {"type": "string"},
                        "dependencies": {
                            "type": "array",
                            "items": {"type": "string"}
                        },
                        "solution_strategy": {"type": "string"}
                    },
                    "required": ["subproblem_id", "description"]
                }
            },
            "relationships": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "from_id": {"type": "string"},
                        "to_id": {"type": "string"},
                        "relationship_type": {
                            "type": "string",
                            "enum": ["depends_on", "influences", "precedes", "enables"]
                        }
                    },
                    "required": ["from_id", "to_id", "relationship_type"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "decomposition_method": {"type": "string"},
                    "confidence_score": {"type": "number", "minimum": 0.0, "maximum": 1.0},
                    "notes": {"type": "string"}
                }
            }
        },
        "required": ["timestamp", "decomposition_id", "original_problem", "subproblems"]
    }
) 