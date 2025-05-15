"""
ConceptMap Schema

This schema defines the structure for representing hierarchical concept organizations,
including relationships, learning objectives, and mastery tracking.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "map_id": "cm_python_basics",
    "root_concept": {
        "id": "python_programming",
        "name": "Python Programming",
        "description": "Fundamentals of Python programming",
        "mastery_level": 0.8,
        "subconcepts": [
            {
                "id": "data_types",
                "name": "Data Types",
                "description": "Basic Python data types",
                "mastery_level": 0.9,
                "prerequisites": []
            },
            {
                "id": "control_flow",
                "name": "Control Flow",
                "description": "Flow control statements",
                "mastery_level": 0.75,
                "prerequisites": ["data_types"]
            }
        ]
    },
    "learning_path": {
        "objective": "Master Python basics",
        "target_mastery": 0.8,
        "current_focus": "control_flow",
        "completed_concepts": ["data_types"]
    },
    "metadata": {
        "domain": "programming",
        "difficulty": "beginner",
        "estimated_duration": 3600
    }
}
```
"""

from lux_sdk.signals import SignalSchema

ConceptMapSchema = SignalSchema(
    name="concept_map",
    version="1.0",
    description="Schema for representing hierarchical concept organizations",
    schema={
        "type": "object",
        "required": ["timestamp", "map_id", "root_concept", "metadata"],
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "Map creation timestamp"
            },
            "map_id": {
                "type": "string",
                "description": "Unique map identifier"
            },
            "root_concept": {
                "type": "object",
                "required": ["id", "name", "description"],
                "properties": {
                    "id": {
                        "type": "string",
                        "description": "Concept identifier"
                    },
                    "name": {
                        "type": "string",
                        "description": "Concept name"
                    },
                    "description": {
                        "type": "string",
                        "description": "Concept description"
                    },
                    "mastery_level": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Current mastery level"
                    },
                    "subconcepts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["id", "name", "description"],
                            "properties": {
                                "id": {
                                    "type": "string",
                                    "description": "Subconcept identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Subconcept name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Subconcept description"
                                },
                                "mastery_level": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Current mastery level"
                                },
                                "prerequisites": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Required concepts"
                                }
                            }
                        }
                    }
                }
            },
            "learning_path": {
                "type": "object",
                "properties": {
                    "objective": {
                        "type": "string",
                        "description": "Learning objective"
                    },
                    "target_mastery": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Target mastery level"
                    },
                    "current_focus": {
                        "type": "string",
                        "description": "Current concept focus"
                    },
                    "completed_concepts": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Completed concept IDs"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "required": ["domain", "difficulty"],
                "properties": {
                    "domain": {
                        "type": "string",
                        "description": "Knowledge domain"
                    },
                    "difficulty": {
                        "type": "string",
                        "enum": ["beginner", "intermediate", "advanced", "expert"],
                        "description": "Content difficulty"
                    },
                    "estimated_duration": {
                        "type": "number",
                        "minimum": 0,
                        "description": "Estimated learning duration in seconds"
                    }
                }
            }
        },
        "additionalProperties": False
    }
) 