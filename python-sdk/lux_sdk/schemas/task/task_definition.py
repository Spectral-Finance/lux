"""
TaskDefinitionSchema

This schema represents a task definition, including its objectives,
requirements, constraints, and success criteria.
"""

from lux_sdk.signals import SignalSchema

TaskDefinitionSchema = SignalSchema(
    name="task_definition",
    version="1.0",
    description="Schema for representing task definitions including objectives, requirements, and success criteria",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time"},
            "task_id": {"type": "string"},
            "title": {"type": "string"},
            "description": {"type": "string"},
            "objectives": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "description": {"type": "string"},
                        "priority": {"type": "integer", "minimum": 1, "maximum": 5},
                        "metrics": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {"type": "string"},
                                    "target": {"type": "number"},
                                    "unit": {"type": "string"}
                                },
                                "required": ["name", "target", "unit"]
                            }
                        }
                    },
                    "required": ["id", "description", "priority"]
                }
            },
            "requirements": {
                "type": "object",
                "properties": {
                    "skills": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "level": {"type": "string", "enum": ["basic", "intermediate", "advanced"]}
                            },
                            "required": ["name", "level"]
                        }
                    },
                    "resources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"},
                                "quantity": {"type": "number"},
                                "availability": {"type": "string"}
                            },
                            "required": ["type", "quantity", "availability"]
                        }
                    },
                    "dependencies": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "task_id": {"type": "string"},
                                "relationship": {"type": "string", "enum": ["blocks", "required_by", "related_to"]}
                            },
                            "required": ["task_id", "relationship"]
                        }
                    }
                }
            },
            "constraints": {
                "type": "object",
                "properties": {
                    "deadline": {"type": "string", "format": "date-time"},
                    "budget": {"type": "number", "minimum": 0},
                    "quality_threshold": {"type": "number", "minimum": 0.0, "maximum": 1.0},
                    "custom_constraints": {"type": "array", "items": {"type": "string"}}
                }
            },
            "success_criteria": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion": {"type": "string"},
                        "measurement": {"type": "string"},
                        "threshold": {"type": "string"}
                    },
                    "required": ["criterion", "measurement", "threshold"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {"type": "string"},
                    "creation_date": {"type": "string", "format": "date-time"},
                    "last_modified": {"type": "string", "format": "date-time"},
                    "status": {"type": "string", "enum": ["draft", "active", "completed", "cancelled"]},
                    "tags": {"type": "array", "items": {"type": "string"}}
                }
            }
        },
        "required": ["timestamp", "task_id", "title", "description", "objectives", "requirements", "success_criteria"]
    }
) 