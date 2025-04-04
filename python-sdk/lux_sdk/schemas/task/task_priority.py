"""
Task Priority Schema

This schema defines the structure for task prioritization,
including priority levels, criteria, and impact assessment.
"""

from lux_sdk.signals import SignalSchema

TaskPrioritySchema = SignalSchema(
    name="task_priority",
    version="1.0",
    description="Schema for defining task priorities and their criteria",
    schema={
        "type": "object",
        "description": "Schema for defining task priorities and their criteria",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the priority was assigned"
            },
            "priority_id": {
                "type": "string",
                "description": "Unique identifier for this priority assignment"
            },
            "task_id": {
                "type": "string",
                "description": "Reference to the task being prioritized"
            },
            "priority_level": {
                "type": "object",
                "description": "The assigned priority level and its justification",
                "properties": {
                    "level": {
                        "type": "string",
                        "enum": ["critical", "high", "medium", "low", "backlog"]
                    },
                    "score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100,
                        "description": "Numerical priority score (0-100)"
                    },
                    "justification": {"type": "string"}
                },
                "required": ["level", "score"]
            },
            "criteria": {
                "type": "array",
                "description": "Criteria used to determine priority",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "weight": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1
                        },
                        "score": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 100
                        },
                        "description": {"type": "string"}
                    },
                    "required": ["name", "weight", "score"]
                }
            },
            "impact_assessment": {
                "type": "object",
                "description": "Assessment of task impact on various aspects",
                "properties": {
                    "business_value": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10
                    },
                    "urgency": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10
                    },
                    "dependencies": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "stakeholders": {
                        "type": "array",
                        "items": {"type": "string"}
                    }
                },
                "required": ["business_value", "urgency"]
            },
            "time_sensitivity": {
                "type": "object",
                "description": "Time-related factors affecting priority",
                "properties": {
                    "deadline": {
                        "type": "string",
                        "format": "date-time"
                    },
                    "time_criticality": {
                        "type": "string",
                        "enum": ["immediate", "time_sensitive", "flexible", "not_time_critical"]
                    },
                    "estimated_delay_impact": {"type": "string"}
                },
                "required": ["time_criticality"]
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the priority assignment",
                "properties": {
                    "assigned_by": {"type": "string"},
                    "assignment_date": {"type": "string", "format": "date-time"},
                    "last_reviewed": {"type": "string", "format": "date-time"},
                    "review_cycle": {
                        "type": "string",
                        "enum": ["daily", "weekly", "monthly", "quarterly"]
                    }
                },
                "required": ["assigned_by", "assignment_date"]
            }
        },
        "required": [
            "timestamp",
            "priority_id",
            "task_id",
            "priority_level",
            "criteria",
            "impact_assessment",
            "metadata"
        ]
    }
) 