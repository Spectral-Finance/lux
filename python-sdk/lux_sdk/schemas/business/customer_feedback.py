"""
Customer Feedback Schema

This schema represents customer feedback and satisfaction data,
including ratings, comments, and response tracking.
"""

from lux_sdk.signals import SignalSchema

CustomerFeedbackSchema = SignalSchema(
    name="customer_feedback",
    version="1.0",
    description="Schema for customer feedback and satisfaction tracking",
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
            "customer_id": {
                "type": "string",
                "description": "Identifier for the customer"
            },
            "product_id": {
                "type": "string",
                "description": "Identifier for the product/service"
            },
            "feedback_type": {
                "type": "string",
                "enum": ["review", "complaint", "suggestion", "inquiry", "praise"],
                "description": "Type of feedback"
            },
            "channel": {
                "type": "string",
                "enum": ["email", "phone", "web", "app", "social_media", "in_person"],
                "description": "Channel through which feedback was received"
            },
            "satisfaction_rating": {
                "type": "object",
                "properties": {
                    "overall": {
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 5,
                        "description": "Overall satisfaction rating (1-5)"
                    },
                    "categories": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "category": {
                                    "type": "string",
                                    "description": "Category being rated"
                                },
                                "rating": {
                                    "type": "integer",
                                    "minimum": 1,
                                    "maximum": 5,
                                    "description": "Rating for this category"
                                }
                            },
                            "required": ["category", "rating"]
                        }
                    }
                },
                "required": ["overall"]
            },
            "content": {
                "type": "object",
                "properties": {
                    "summary": {
                        "type": "string",
                        "description": "Brief summary of the feedback"
                    },
                    "details": {
                        "type": "string",
                        "description": "Detailed feedback content"
                    },
                    "attachments": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of attachment"
                                },
                                "url": {
                                    "type": "string",
                                    "description": "URL to the attachment"
                                }
                            }
                        }
                    }
                },
                "required": ["summary"]
            },
            "sentiment_analysis": {
                "type": "object",
                "properties": {
                    "sentiment": {
                        "type": "string",
                        "enum": ["positive", "neutral", "negative"],
                        "description": "Overall sentiment of feedback"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence score of sentiment analysis"
                    },
                    "key_phrases": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Key phrases extracted from feedback"
                    }
                }
            },
            "response": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["pending", "in_progress", "resolved", "closed"],
                        "description": "Status of response to feedback"
                    },
                    "assigned_to": {
                        "type": "string",
                        "description": "ID of person/team assigned to handle"
                    },
                    "response_details": {
                        "type": "string",
                        "description": "Details of the response"
                    },
                    "response_time": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When response was provided"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the feedback record"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "updated_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "source": {
                        "type": "string",
                        "description": "Source of the feedback"
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
        "required": ["timestamp", "feedback_id", "customer_id", "feedback_type", "content"]
    }
) 