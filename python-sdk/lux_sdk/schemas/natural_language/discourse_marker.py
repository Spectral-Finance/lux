"""
Discourse Marker Schema

This schema represents discourse markers and connectives in natural language,
including their types, functions, and relationships between text segments.
"""

from lux_sdk.signals import SignalSchema

DiscourseMarkerSchema = SignalSchema(
    name="discourse_marker",
    version="1.0",
    description="Schema for discourse markers and connectives in natural language",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "marker_id": {
                "type": "string",
                "description": "Unique identifier for this discourse marker instance"
            },
            "text": {
                "type": "string",
                "description": "Full text containing the discourse marker"
            },
            "marker": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "The actual discourse marker text"
                    },
                    "position": {
                        "type": "object",
                        "properties": {
                            "start": {
                                "type": "integer",
                                "description": "Start position in text"
                            },
                            "end": {
                                "type": "integer",
                                "description": "End position in text"
                            }
                        },
                        "required": ["start", "end"]
                    },
                    "type": {
                        "type": "string",
                        "enum": [
                            "coordinating_conjunction",
                            "subordinating_conjunction",
                            "conjunctive_adverb",
                            "prepositional_phrase",
                            "other"
                        ],
                        "description": "Grammatical type of the marker"
                    },
                    "function": {
                        "type": "string",
                        "enum": [
                            "addition",
                            "contrast",
                            "cause",
                            "consequence",
                            "condition",
                            "temporal",
                            "exemplification",
                            "reformulation",
                            "conclusion"
                        ],
                        "description": "Discourse function of the marker"
                    }
                },
                "required": ["text", "type", "function"]
            },
            "segments": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "Text segment"
                        },
                        "position": {
                            "type": "object",
                            "properties": {
                                "start": {
                                    "type": "integer",
                                    "description": "Start position in text"
                                },
                                "end": {
                                    "type": "integer",
                                    "description": "End position in text"
                                }
                            },
                            "required": ["start", "end"]
                        },
                        "role": {
                            "type": "string",
                            "enum": ["arg1", "arg2"],
                            "description": "Role of the segment in the relation"
                        }
                    },
                    "required": ["text", "role"]
                },
                "minItems": 2,
                "maxItems": 2,
                "description": "Text segments connected by the discourse marker"
            },
            "coherence_relations": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": [
                            "temporal",
                            "causal",
                            "comparison",
                            "expansion",
                            "contingency"
                        ],
                        "description": "Type of coherence relation"
                    },
                    "subtype": {
                        "type": "string",
                        "description": "Specific subtype of the relation"
                    },
                    "direction": {
                        "type": "string",
                        "enum": ["forward", "backward", "bidirectional"],
                        "description": "Direction of the relation"
                    },
                    "strength": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Strength of the coherence relation"
                    }
                },
                "required": ["type"]
            },
            "context": {
                "type": "object",
                "properties": {
                    "document_id": {
                        "type": "string",
                        "description": "ID of the source document"
                    },
                    "paragraph_id": {
                        "type": "string",
                        "description": "ID of the paragraph"
                    },
                    "sentence_id": {
                        "type": "string",
                        "description": "ID of the sentence"
                    },
                    "genre": {
                        "type": "string",
                        "description": "Genre of the text"
                    },
                    "register": {
                        "type": "string",
                        "enum": ["formal", "informal", "technical", "casual"],
                        "description": "Register of the text"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "annotator": {
                        "type": "string",
                        "description": "ID of the annotator"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence score of the annotation"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language of the text"
                    },
                    "model_version": {
                        "type": "string",
                        "description": "Version of the model used"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes about the annotation"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "marker_id",
            "text",
            "marker",
            "segments"
        ]
    }
) 