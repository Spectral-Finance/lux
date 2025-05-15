"""
Clarification Schema

This schema represents clarification requests and responses in natural language processing,
including ambiguity resolution, context specification, and information seeking.
"""

from lux_sdk.signals import SignalSchema

ClarificationSchema = SignalSchema(
    name="clarification",
    version="1.0",
    description="Schema for clarification requests and responses in natural language processing",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "clarification_id": {
                "type": "string",
                "description": "Unique identifier for this clarification interaction"
            },
            "context": {
                "type": "object",
                "properties": {
                    "original_text": {
                        "type": "string",
                        "description": "Original text requiring clarification"
                    },
                    "source": {
                        "type": "string",
                        "description": "Source of the original text"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language of the text"
                    },
                    "domain": {
                        "type": "string",
                        "description": "Domain or subject area"
                    }
                },
                "required": ["original_text"]
            },
            "ambiguity": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["lexical", "syntactic", "semantic", "pragmatic", "reference", "scope"],
                        "description": "Type of ambiguity"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the ambiguity"
                    },
                    "span": {
                        "type": "object",
                        "properties": {
                            "start": {
                                "type": "integer",
                                "description": "Start position of ambiguous text"
                            },
                            "end": {
                                "type": "integer",
                                "description": "End position of ambiguous text"
                            },
                            "text": {
                                "type": "string",
                                "description": "Ambiguous text segment"
                            }
                        },
                        "required": ["start", "end", "text"]
                    },
                    "possible_interpretations": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "interpretation": {
                                    "type": "string",
                                    "description": "Possible interpretation"
                                },
                                "confidence": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Confidence in this interpretation"
                                }
                            },
                            "required": ["interpretation"]
                        }
                    }
                },
                "required": ["type", "description"]
            },
            "clarification_request": {
                "type": "object",
                "properties": {
                    "question": {
                        "type": "string",
                        "description": "Clarification question"
                    },
                    "type": {
                        "type": "string",
                        "enum": ["yes_no", "multiple_choice", "open_ended", "confirmation"],
                        "description": "Type of clarification request"
                    },
                    "options": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Possible response options"
                        }
                    },
                    "priority": {
                        "type": "string",
                        "enum": ["low", "medium", "high"],
                        "description": "Priority of the clarification"
                    }
                },
                "required": ["question", "type"]
            },
            "response": {
                "type": "object",
                "properties": {
                    "content": {
                        "type": "string",
                        "description": "Clarification response content"
                    },
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the response was received"
                    },
                    "source": {
                        "type": "string",
                        "description": "Source of the response"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in the response"
                    }
                },
                "required": ["content"]
            },
            "resolution": {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["pending", "resolved", "partially_resolved", "unresolved"],
                        "description": "Resolution status"
                    },
                    "resolved_text": {
                        "type": "string",
                        "description": "Text with ambiguity resolved"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in resolution"
                    },
                    "resolution_method": {
                        "type": "string",
                        "description": "Method used to resolve ambiguity"
                    }
                },
                "required": ["status"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "system": {
                        "type": "string",
                        "description": "System generating clarification"
                    },
                    "model_version": {
                        "type": "string",
                        "description": "Version of the model"
                    },
                    "processing_time": {
                        "type": "number",
                        "description": "Time taken to process in milliseconds"
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
            "clarification_id",
            "context",
            "ambiguity",
            "clarification_request"
        ]
    }
) 