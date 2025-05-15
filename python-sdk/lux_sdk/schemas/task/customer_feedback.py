"""
Customer Feedback Schema

This schema represents customer feedback and satisfaction assessment,
including ratings, comments, sentiment analysis, and response tracking.
"""

from lux_sdk.signals import SignalSchema

CustomerFeedbackSchema = SignalSchema(
    name="customer_feedback",
    version="1.0",
    description="Schema for customer feedback and satisfaction assessment",
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
            "customer_info": {
                "type": "object",
                "properties": {
                    "customer_id": {
                        "type": "string",
                        "description": "Unique identifier for the customer"
                    },
                    "segment": {
                        "type": "string",
                        "description": "Customer segment or category"
                    },
                    "region": {
                        "type": "string",
                        "description": "Geographic region"
                    },
                    "interaction_history": {
                        "type": "object",
                        "properties": {
                            "first_interaction": {
                                "type": "string",
                                "format": "date-time"
                            },
                            "total_interactions": {
                                "type": "integer",
                                "minimum": 0
                            },
                            "last_interaction": {
                                "type": "string",
                                "format": "date-time"
                            }
                        }
                    }
                },
                "required": ["customer_id"]
            },
            "feedback_source": {
                "type": "object",
                "properties": {
                    "channel": {
                        "type": "string",
                        "enum": ["email", "web", "mobile_app", "phone", "social_media", "in_person"],
                        "description": "Channel through which feedback was received"
                    },
                    "touchpoint": {
                        "type": "string",
                        "description": "Specific interaction point"
                    },
                    "product_service": {
                        "type": "string",
                        "description": "Product or service being reviewed"
                    },
                    "interaction_id": {
                        "type": "string",
                        "description": "ID of the specific interaction"
                    }
                },
                "required": ["channel"]
            },
            "ratings": {
                "type": "object",
                "properties": {
                    "overall_satisfaction": {
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 5,
                        "description": "Overall satisfaction score (1-5)"
                    },
                    "nps": {
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 10,
                        "description": "Net Promoter Score (0-10)"
                    },
                    "specific_ratings": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "aspect": {
                                    "type": "string",
                                    "description": "Aspect being rated"
                                },
                                "score": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 5,
                                    "description": "Rating score"
                                },
                                "weight": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Weight of this aspect"
                                }
                            },
                            "required": ["aspect", "score"]
                        }
                    }
                },
                "required": ["overall_satisfaction"]
            },
            "feedback_content": {
                "type": "object",
                "properties": {
                    "comments": {
                        "type": "string",
                        "description": "Customer comments or feedback text"
                    },
                    "sentiment_analysis": {
                        "type": "object",
                        "properties": {
                            "sentiment": {
                                "type": "string",
                                "enum": ["very_negative", "negative", "neutral", "positive", "very_positive"],
                                "description": "Overall sentiment"
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Confidence in sentiment analysis"
                            },
                            "aspects": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "topic": {
                                            "type": "string",
                                            "description": "Topic or aspect mentioned"
                                        },
                                        "sentiment": {
                                            "type": "string",
                                            "enum": ["very_negative", "negative", "neutral", "positive", "very_positive"]
                                        },
                                        "mentions": {
                                            "type": "integer",
                                            "minimum": 1
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "categories": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Categories or tags for the feedback"
                    }
                }
            },
            "response_tracking": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["new", "in_progress", "responded", "resolved", "closed"],
                        "description": "Status of feedback response"
                    },
                    "priority": {
                        "type": "string",
                        "enum": ["low", "medium", "high", "urgent"],
                        "description": "Priority level for response"
                    },
                    "assigned_to": {
                        "type": "string",
                        "description": "Person or team assigned to respond"
                    },
                    "response_history": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time"
                                },
                                "action": {
                                    "type": "string",
                                    "description": "Action taken"
                                },
                                "response": {
                                    "type": "string",
                                    "description": "Response content"
                                },
                                "responder": {
                                    "type": "string",
                                    "description": "Person who responded"
                                }
                            },
                            "required": ["timestamp", "action"]
                        }
                    }
                },
                "required": ["status"]
            },
            "follow_up": {
                "type": "object",
                "properties": {
                    "required": {
                        "type": "boolean",
                        "description": "Whether follow-up is required"
                    },
                    "type": {
                        "type": "string",
                        "enum": ["survey", "call", "email", "meeting"],
                        "description": "Type of follow-up"
                    },
                    "due_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When follow-up should occur"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes for follow-up"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "version": {
                        "type": "string",
                        "description": "Version of the feedback form"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language of the feedback"
                    },
                    "platform": {
                        "type": "string",
                        "description": "Platform used to collect feedback"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "feedback_id",
            "customer_info",
            "feedback_source",
            "ratings",
            "feedback_content",
            "response_tracking"
        ]
    }
) 