"""
TeamFormationSchema

This schema represents team formation parameters and criteria,
including team composition, roles, and formation strategies.
"""

from lux_sdk.signals import SignalSchema

TeamFormationSchema = SignalSchema(
    name="team_formation",
    version="1.0",
    description="Schema for representing team formation parameters and criteria",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "formation_id": {"type": "string", "required": True},
            "project": {
                "type": "object",
                "required": True,
                "properties": {
                    "id": {"type": "string", "required": True},
                    "name": {"type": "string", "required": True},
                    "description": {"type": "string", "required": True},
                    "duration": {"type": "string", "required": True},
                    "complexity": {"type": "string", "enum": ["low", "medium", "high"], "required": True}
                }
            },
            "team_requirements": {
                "type": "object",
                "required": True,
                "properties": {
                    "size": {
                        "type": "object",
                        "properties": {
                            "min": {"type": "integer", "minimum": 1, "required": True},
                            "max": {"type": "integer", "minimum": 1, "required": True},
                            "optimal": {"type": "integer", "minimum": 1}
                        }
                    },
                    "roles": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "title": {"type": "string", "required": True},
                                "count": {"type": "integer", "minimum": 1, "required": True},
                                "skills": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "name": {"type": "string", "required": True},
                                            "level": {"type": "string", "enum": ["basic", "intermediate", "advanced"], "required": True},
                                            "priority": {"type": "integer", "minimum": 1, "maximum": 5}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "formation_criteria": {
                "type": "object",
                "required": True,
                "properties": {
                    "diversity_factors": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "factor": {"type": "string", "required": True},
                                "weight": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True}
                            }
                        }
                    },
                    "compatibility_metrics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "metric": {"type": "string", "required": True},
                                "threshold": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True}
                            }
                        }
                    }
                }
            },
            "constraints": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "object",
                        "properties": {
                            "type": {"type": "string", "enum": ["remote", "onsite", "hybrid"]},
                            "timezone_range": {"type": "integer", "minimum": 0, "maximum": 12}
                        }
                    },
                    "availability": {
                        "type": "object",
                        "properties": {
                            "min_hours_per_week": {"type": "integer", "minimum": 1},
                            "preferred_working_hours": {
                                "type": "array",
                                "items": {"type": "string", "format": "time"}
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {"type": "string"},
                    "creation_date": {"type": "string", "format": "date-time"},
                    "last_modified": {"type": "string", "format": "date-time"},
                    "status": {"type": "string", "enum": ["draft", "in_progress", "completed", "cancelled"]},
                    "tags": {"type": "array", "items": {"type": "string"}}
                }
            }
        }
    }
) 