"""
Competency Level Schema

This schema defines the structure for competency levels in education,
including skills, knowledge areas, and proficiency measurements.
"""

from lux_sdk.signals import SignalSchema

CompetencyLevelSchema = SignalSchema(
    name="competency_level",
    version="1.0",
    description="Schema for defining and tracking competency levels in educational contexts",
    schema={
        "type": "object",
        "description": "Schema for defining and tracking competency levels",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the competency level was assessed"
            },
            "competency_id": {
                "type": "string",
                "description": "Unique identifier for this competency assessment"
            },
            "learner_id": {
                "type": "string",
                "description": "Identifier of the learner being assessed"
            },
            "subject_area": {
                "type": "object",
                "description": "The subject or domain of competency",
                "properties": {
                    "name": {"type": "string"},
                    "code": {"type": "string"},
                    "description": {"type": "string"},
                    "category": {"type": "string"}
                },
                "required": ["name", "description"]
            },
            "competency_framework": {
                "type": "object",
                "description": "Framework used for competency assessment",
                "properties": {
                    "name": {"type": "string"},
                    "version": {"type": "string"},
                    "levels": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "level": {"type": "string"},
                                "description": {"type": "string"},
                                "criteria": {
                                    "type": "array",
                                    "items": {"type": "string"}
                                }
                            },
                            "required": ["level", "description"]
                        }
                    }
                },
                "required": ["name", "version", "levels"]
            },
            "skills_assessment": {
                "type": "array",
                "description": "Assessment of individual skills within the competency",
                "items": {
                    "type": "object",
                    "properties": {
                        "skill_id": {"type": "string"},
                        "name": {"type": "string"},
                        "proficiency_level": {
                            "type": "string",
                            "enum": [
                                "novice",
                                "beginner",
                                "intermediate",
                                "advanced",
                                "expert",
                                "master"
                            ]
                        },
                        "score": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 100
                        },
                        "evidence": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {"type": "string"},
                                    "description": {"type": "string"},
                                    "date": {"type": "string", "format": "date"},
                                    "url": {"type": "string"}
                                },
                                "required": ["type", "description"]
                            }
                        }
                    },
                    "required": ["skill_id", "name", "proficiency_level"]
                }
            },
            "knowledge_areas": {
                "type": "array",
                "description": "Assessment of knowledge areas within the competency",
                "items": {
                    "type": "object",
                    "properties": {
                        "area_id": {"type": "string"},
                        "name": {"type": "string"},
                        "understanding_level": {
                            "type": "string",
                            "enum": [
                                "awareness",
                                "basic",
                                "comprehensive",
                                "expert",
                                "thought_leader"
                            ]
                        },
                        "assessment_details": {
                            "type": "object",
                            "properties": {
                                "method": {"type": "string"},
                                "score": {"type": "number"},
                                "feedback": {"type": "string"}
                            }
                        }
                    },
                    "required": ["area_id", "name", "understanding_level"]
                }
            },
            "development_plan": {
                "type": "object",
                "description": "Plan for competency development",
                "properties": {
                    "goals": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "goal_id": {"type": "string"},
                                "description": {"type": "string"},
                                "target_level": {"type": "string"},
                                "timeline": {"type": "string", "format": "date"},
                                "resources": {
                                    "type": "array",
                                    "items": {"type": "string"}
                                }
                            },
                            "required": ["goal_id", "description", "target_level"]
                        }
                    },
                    "recommendations": {
                        "type": "array",
                        "items": {"type": "string"}
                    }
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the competency assessment",
                "properties": {
                    "assessor": {"type": "string"},
                    "assessment_date": {"type": "string", "format": "date"},
                    "next_review_date": {"type": "string", "format": "date"},
                    "assessment_method": {"type": "string"},
                    "certification": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "issuer": {"type": "string"},
                            "valid_until": {"type": "string", "format": "date"}
                        }
                    }
                },
                "required": ["assessor", "assessment_date", "assessment_method"]
            }
        },
        "required": [
            "timestamp",
            "competency_id",
            "learner_id",
            "subject_area",
            "competency_framework",
            "skills_assessment",
            "metadata"
        ]
    }) 