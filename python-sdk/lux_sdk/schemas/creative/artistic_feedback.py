"""
Artistic Feedback Schema

This schema represents feedback and critique elements for creative works,
including evaluations, suggestions, and improvement areas.
"""

from lux_sdk.signals import SignalSchema

ArtisticFeedbackSchema = SignalSchema(
    name="artistic_feedback",
    version="1.0",
    description="Schema for artistic feedback and critique",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "feedback_id": {
                "type": "string",
                "description": "Unique identifier for this feedback"
            },
            "artwork_id": {
                "type": "string",
                "description": "Reference to the artwork being critiqued"
            },
            "reviewer": {
                "type": "string",
                "description": "Name or identifier of the reviewer"
            },
            "overall_impression": {
                "type": "object",
                "properties": {
                    "rating": {
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 10,
                        "description": "Overall rating (1-10)"
                    },
                    "summary": {
                        "type": "string",
                        "description": "Brief summary of overall impression"
                    }
                },
                "required": ["rating", "summary"]
            },
            "technical_evaluation": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "aspect": {
                            "type": "string",
                            "description": "Technical aspect being evaluated"
                        },
                        "rating": {
                            "type": "integer",
                            "minimum": 1,
                            "maximum": 10
                        },
                        "comments": {
                            "type": "string",
                            "description": "Specific comments about this aspect"
                        }
                    },
                    "required": ["aspect", "rating", "comments"]
                }
            },
            "artistic_elements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "element": {
                            "type": "string",
                            "description": "Artistic element being discussed"
                        },
                        "strengths": {
                            "type": "array",
                            "items": {"type": "string"}
                        },
                        "areas_for_improvement": {
                            "type": "array",
                            "items": {"type": "string"}
                        }
                    },
                    "required": ["element"]
                }
            },
            "suggestions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "category": {
                            "type": "string",
                            "description": "Category of suggestion"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed suggestion"
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["high", "medium", "low"],
                            "description": "Priority level of the suggestion"
                        }
                    },
                    "required": ["category", "description"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the feedback"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the feedback"
                    },
                    "context": {
                        "type": "object",
                        "description": "Additional context about the feedback session"
                    }
                }
            }
        },
        "required": ["timestamp", "feedback_id", "artwork_id", "reviewer", "overall_impression"]
    }
) 