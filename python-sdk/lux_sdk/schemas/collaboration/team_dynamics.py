"""
Team Dynamics Schema

This schema defines the structure for tracking and analyzing team dynamics,
including interaction patterns, collaboration effectiveness, and team health metrics.
"""

from lux_sdk.signals import SignalSchema

TeamDynamicsSchema = SignalSchema(
    name="team_dynamics",
    version="1.0",
    description="Schema for analyzing team dynamics and interactions",
    schema={
        "type": "object",
        "description": "Schema for analyzing team dynamics and interactions",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the team dynamics were assessed"
            },
            "dynamics_id": {
                "type": "string",
                "description": "Unique identifier for this team dynamics assessment"
            },
            "team_id": {
                "type": "string",
                "description": "Reference to the team being analyzed"
            },
            "interaction_patterns": {
                "type": "array",
                "description": "Patterns of team member interactions",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": [
                                "communication",
                                "collaboration",
                                "conflict",
                                "decision_making",
                                "problem_solving",
                                "social"
                            ]
                        },
                        "frequency": {
                            "type": "string",
                            "enum": ["rare", "occasional", "frequent", "constant"]
                        },
                        "quality": {
                            "type": "string",
                            "enum": ["poor", "fair", "good", "excellent"]
                        },
                        "participants": {
                            "type": "array",
                            "items": {"type": "string"}
                        },
                        "context": {"type": "string"}
                    },
                    "required": ["type", "frequency", "quality"]
                }
            },
            "collaboration_metrics": {
                "type": "object",
                "description": "Metrics measuring collaboration effectiveness",
                "properties": {
                    "communication_effectiveness": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10
                    },
                    "decision_making_efficiency": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10
                    },
                    "conflict_resolution": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10
                    },
                    "trust_level": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10
                    }
                },
                "required": ["communication_effectiveness", "trust_level"]
            },
            "team_health": {
                "type": "object",
                "description": "Indicators of overall team health",
                "properties": {
                    "morale": {
                        "type": "string",
                        "enum": ["low", "moderate", "high"]
                    },
                    "engagement": {
                        "type": "string",
                        "enum": ["disengaged", "partially_engaged", "fully_engaged"]
                    },
                    "alignment": {
                        "type": "string",
                        "enum": ["misaligned", "partially_aligned", "fully_aligned"]
                    },
                    "stress_level": {
                        "type": "string",
                        "enum": ["low", "moderate", "high", "critical"]
                    }
                },
                "required": ["morale", "engagement"]
            },
            "improvement_areas": {
                "type": "array",
                "description": "Areas identified for team improvement",
                "items": {
                    "type": "object",
                    "properties": {
                        "area": {"type": "string"},
                        "priority": {
                            "type": "string",
                            "enum": ["low", "medium", "high"]
                        },
                        "current_state": {"type": "string"},
                        "target_state": {"type": "string"},
                        "action_items": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    },
                    "required": ["area", "priority", "current_state", "target_state"]
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the team dynamics assessment",
                "properties": {
                    "assessor": {"type": "string"},
                    "assessment_method": {"type": "string"},
                    "assessment_period": {
                        "type": "object",
                        "properties": {
                            "start_date": {"type": "string", "format": "date-time"},
                            "end_date": {"type": "string", "format": "date-time"}
                        },
                        "required": ["start_date", "end_date"]
                    },
                    "next_review_date": {"type": "string", "format": "date-time"}
                },
                "required": ["assessor", "assessment_method", "assessment_period"]
            }
        },
        "required": [
            "timestamp",
            "dynamics_id",
            "team_id",
            "interaction_patterns",
            "collaboration_metrics",
            "team_health",
            "metadata"
        ]
    }) 