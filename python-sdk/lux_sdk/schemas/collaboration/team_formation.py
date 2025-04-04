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
            "timestamp": {"type": "string", "format": "date-time"},
            "formation_id": {"type": "string"},
            "project": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "description": {"type": "string"},
                    "duration": {"type": "string"},
                    "complexity": {"type": "string", "enum": ["low", "medium", "high"]}
                },
                "required": ["id", "name", "description", "duration", "complexity"]
            },
            "team_requirements": {
                "type": "object",
                "properties": {
                    "size": {
                        "type": "object",
                        "properties": {
                            "min": {"type": "integer", "minimum": 1},
                            "max": {"type": "integer", "minimum": 1},
                            "optimal": {"type": "integer", "minimum": 1}
                        },
                        "required": ["min", "max"]
                    },
                    "roles": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "title": {"type": "string"},
                                "count": {"type": "integer", "minimum": 1},
                                "skills": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "name": {"type": "string"},
                                            "level": {"type": "string", "enum": ["basic", "intermediate", "advanced"]},
                                            "priority": {"type": "integer", "minimum": 1, "maximum": 5}
                                        },
                                        "required": ["name", "level"]
                                    }
                                }
                            },
                            "required": ["title", "count"]
                        }
                    }
                },
                "required": ["size", "roles"]
            },
            "formation_criteria": {
                "type": "object",
                "properties": {
                    "diversity_factors": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "factor": {"type": "string"},
                                "weight": {"type": "number", "minimum": 0.0, "maximum": 1.0}
                            },
                            "required": ["factor", "weight"]
                        }
                    },
                    "compatibility_metrics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "metric": {"type": "string"},
                                "threshold": {"type": "number", "minimum": 0.0, "maximum": 1.0}
                            },
                            "required": ["metric", "threshold"]
                        }
                    }
                },
                "required": ["diversity_factors", "compatibility_metrics"]
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
        },
        "required": ["timestamp", "formation_id", "project", "team_requirements", "formation_criteria"]
    }
) 