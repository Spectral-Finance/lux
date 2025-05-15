"""
Semantic Frame Schema

This schema represents semantic frames in natural language processing,
including frame elements, roles, and semantic relationships.
"""

from lux_sdk.signals import SignalSchema

SemanticFrameSchema = SignalSchema(
    name="semantic_frame",
    version="1.0",
    description="Schema for representing semantic frames and their elements in text analysis",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "frame_id": {
                "type": "string",
                "description": "Unique identifier for this semantic frame"
            },
            "text": {
                "type": "string",
                "description": "Source text containing the semantic frame"
            },
            "frame_type": {
                "type": "string",
                "description": "Type or category of the semantic frame"
            },
            "frame_elements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "element_id": {
                            "type": "string",
                            "description": "Identifier for the frame element"
                        },
                        "role": {
                            "type": "string",
                            "description": "Semantic role of the element"
                        },
                        "text_span": {
                            "type": "object",
                            "properties": {
                                "start": {
                                    "type": "integer",
                                    "description": "Start index in the source text"
                                },
                                "end": {
                                    "type": "integer",
                                    "description": "End index in the source text"
                                },
                                "text": {
                                    "type": "string",
                                    "description": "Actual text of the element"
                                }
                            },
                            "required": ["start", "end", "text"]
                        },
                        "properties": {
                            "type": "object",
                            "description": "Additional properties of the element"
                        }
                    },
                    "required": ["element_id", "role", "text_span"]
                }
            },
            "relationships": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "source_id": {
                            "type": "string",
                            "description": "ID of the source element"
                        },
                        "target_id": {
                            "type": "string",
                            "description": "ID of the target element"
                        },
                        "relation_type": {
                            "type": "string",
                            "description": "Type of semantic relationship"
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Confidence score for the relationship"
                        }
                    },
                    "required": ["source_id", "target_id", "relation_type"]
                }
            },
            "annotations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "description": "Type of annotation"
                        },
                        "value": {
                            "description": "Annotation value"
                        },
                        "span": {
                            "type": "object",
                            "properties": {
                                "start": {
                                    "type": "integer",
                                    "description": "Start index"
                                },
                                "end": {
                                    "type": "integer",
                                    "description": "End index"
                                }
                            },
                            "required": ["start", "end"]
                        }
                    },
                    "required": ["type", "value"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "language": {
                        "type": "string",
                        "description": "Language of the text"
                    },
                    "frame_net_id": {
                        "type": "string",
                        "description": "Reference to FrameNet frame if applicable"
                    },
                    "confidence_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Overall confidence in frame analysis"
                    },
                    "processing_info": {
                        "type": "object",
                        "properties": {
                            "model_version": {
                                "type": "string",
                                "description": "Version of the semantic parsing model"
                            },
                            "processing_time": {
                                "type": "number",
                                "description": "Time taken to analyze in milliseconds"
                            }
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "frame_id", "text", "frame_type", "frame_elements"]
    }
) 