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
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "task_id": {"type": "string", "required": True},
            "title": {"type": "string", "required": True},
            "description": {"type": "string", "required": True},
            "objectives": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "priority": {"type": "integer", "minimum": 1, "maximum": 5, "required": True},
                        "metrics": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {"type": "string", "required": True},
                                    "target": {"type": "number", "required": True},
                                    "unit": {"type": "string", "required": True}
                                }
                            }
                        }
                    }
                }
            },
            "requirements": {
                "type": "object",
                "required": True,
                "properties": {
                    "skills": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "level": {"type": "string", "enum": ["basic", "intermediate", "advanced"], "required": True}
                            }
                        }
                    },
                    "resources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string", "required": True},
                                "quantity": {"type": "number", "required": True},
                                "availability": {"type": "string", "required": True}
                            }
                        }
                    },
                    "dependencies": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "task_id": {"type": "string", "required": True},
                                "relationship": {"type": "string", "enum": ["blocks", "required_by", "related_to"], "required": True}
                            }
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
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion": {"type": "string", "required": True},
                        "measurement": {"type": "string", "required": True},
                        "threshold": {"type": "string", "required": True}
                    }
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
        }
    }
) 