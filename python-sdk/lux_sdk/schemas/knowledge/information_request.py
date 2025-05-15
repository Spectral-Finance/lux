"""
Information Request Schema

This schema represents requests for information or knowledge retrieval,
including query specifications, context, and response requirements.
"""

from lux_sdk.signals import SignalSchema

InformationRequestSchema = SignalSchema(
    name="information_request",
    version="1.0",
    description="Schema for representing information and knowledge retrieval requests",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "request_id": {
                "type": "string",
                "description": "Unique identifier for the information request"
            },
            "query": {
                "type": "object",
                "properties": {
                    "query_text": {
                        "type": "string",
                        "description": "The actual query or question being asked"
                    },
                    "query_type": {
                        "type": "string",
                        "enum": ["factual", "conceptual", "procedural", "analytical"],
                        "description": "Type of information being requested"
                    },
                    "domain": {
                        "type": "string",
                        "description": "Knowledge domain of the query"
                    }
                },
                "required": ["query_text", "query_type"]
            },
            "context": {
                "type": "object",
                "properties": {
                    "background_info": {
                        "type": "string",
                        "description": "Relevant background information"
                    },
                    "purpose": {
                        "type": "string",
                        "description": "Purpose of the information request"
                    },
                    "constraints": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Any constraints on the requested information"
                    }
                }
            },
            "response_requirements": {
                "type": "object",
                "properties": {
                    "format": {
                        "type": "string",
                        "enum": ["text", "structured", "numeric", "visual"],
                        "description": "Required format of the response"
                    },
                    "detail_level": {
                        "type": "string",
                        "enum": ["brief", "detailed", "comprehensive"],
                        "description": "Required level of detail in the response"
                    },
                    "max_length": {
                        "type": "integer",
                        "description": "Maximum length of the response"
                    }
                },
                "required": ["format", "detail_level"]
            },
            "priority": {
                "type": "object",
                "properties": {
                    "urgency": {
                        "type": "string",
                        "enum": ["low", "medium", "high", "critical"],
                        "description": "Urgency level of the request"
                    },
                    "importance": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Importance score of the request"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "requester_id": {
                        "type": "string",
                        "description": "Identifier of the entity making the request"
                    },
                    "source_system": {
                        "type": "string",
                        "description": "System originating the request"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Tags for categorizing the request"
                    }
                }
            }
        },
        "required": ["timestamp", "request_id", "query", "response_requirements"]
    }
) 