"""
Expertise Level Schema

This schema represents expertise level assessment and tracking,
including skill proficiency, knowledge depth, and experience metrics.
"""

from lux_sdk.signals import SignalSchema

ExpertiseLevelSchema = SignalSchema(
    name="expertise_level",
    version="1.0",
    description="Schema for expertise level assessment and tracking",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "assessment_id": {
                "type": "string",
                "description": "Unique identifier for this expertise assessment"
            },
            "subject_id": {
                "type": "string",
                "description": "Identifier of the subject being assessed"
            },
            "domain": {
                "type": "string",
                "description": "Domain or field of expertise"
            },
            "expertise_rating": {
                "type": "object",
                "properties": {
                    "level": {
                        "type": "string",
                        "enum": ["novice", "intermediate", "advanced", "expert", "master"],
                        "description": "Overall expertise level"
                    },
                    "numerical_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100,
                        "description": "Numerical expertise score"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in the assessment"
                    }
                },
                "required": ["level"]
            },
            "skill_assessment": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "skill_id": {
                            "type": "string",
                            "description": "Identifier for the skill"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the skill"
                        },
                        "proficiency": {
                            "type": "string",
                            "enum": ["none", "basic", "intermediate", "advanced", "expert"],
                            "description": "Proficiency level in this skill"
                        },
                        "experience": {
                            "type": "object",
                            "properties": {
                                "years": {
                                    "type": "number",
                                    "description": "Years of experience"
                                },
                                "projects": {
                                    "type": "integer",
                                    "description": "Number of related projects"
                                }
                            }
                        }
                    },
                    "required": ["skill_id", "name", "proficiency"]
                }
            },
            "knowledge_areas": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "area_id": {
                            "type": "string",
                            "description": "Identifier for the knowledge area"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the knowledge area"
                        },
                        "depth": {
                            "type": "string",
                            "enum": ["surface", "working", "deep", "comprehensive"],
                            "description": "Depth of knowledge"
                        },
                        "last_updated": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When knowledge was last updated"
                        }
                    },
                    "required": ["area_id", "name", "depth"]
                }
            },
            "certifications": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "certification_id": {
                            "type": "string",
                            "description": "Identifier for the certification"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of certification"
                        },
                        "issuer": {
                            "type": "string",
                            "description": "Certification issuer"
                        },
                        "date_earned": {
                            "type": "string",
                            "format": "date",
                            "description": "When certification was earned"
                        },
                        "expiry_date": {
                            "type": "string",
                            "format": "date",
                            "description": "When certification expires"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["active", "expired", "pending"],
                            "description": "Current status of certification"
                        }
                    },
                    "required": ["certification_id", "name", "issuer", "date_earned"]
                }
            },
            "experience_metrics": {
                "type": "object",
                "properties": {
                    "total_years": {
                        "type": "number",
                        "description": "Total years of experience in the domain"
                    },
                    "project_count": {
                        "type": "integer",
                        "description": "Number of relevant projects"
                    },
                    "contributions": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of contribution"
                                },
                                "impact": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high"],
                                    "description": "Impact level of contribution"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of contribution"
                                }
                            },
                            "required": ["type", "impact"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "assessor": {
                        "type": "string",
                        "description": "ID of the assessor"
                    },
                    "assessment_method": {
                        "type": "string",
                        "description": "Method used for assessment"
                    },
                    "assessment_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When assessment was performed"
                    },
                    "next_review": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When expertise should be reassessed"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes about the assessment"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "assessment_id",
            "subject_id",
            "domain",
            "expertise_rating",
            "skill_assessment"
        ]
    }
) 