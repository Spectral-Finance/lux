"""
Discourse Marker Schema

This schema represents discourse markers and connectives in natural language,
including their types, functions, and relationships in text.
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
                "description": "Unique identifier for this discourse marker annotation"
            },
            "text": {
                "type": "string",
                "description": "The text containing the discourse marker"
            },
            "marker": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "The discourse marker text"
                    },
                    "position": {
                        "type": "object",
                        "properties": {
                            "start": {
                                "type": "integer",
                                "description": "Start character position"
                            },
                            "end": {
                                "type": "integer",
                                "description": "End character position"
                            }
                        },
                        "required": ["start", "end"]
                    },
                    "type": {
                        "type": "string",
                        "enum": [
                            "conjunction",
                            "disjunction",
                            "contrast",
                            "cause",
                            "consequence",
                            "condition",
                            "temporal",
                            "elaboration",
                            "exemplification",
                            "reformulation",
                            "other"
                        ],
                        "description": "Type of discourse marker"
                    },
                    "function": {
                        "type": "string",
                        "enum": [
                            "additive",
                            "adversative",
                            "causal",
                            "temporal",
                            "conditional",
                            "comparative",
                            "illustrative",
                            "sequential",
                            "emphatic",
                            "other"
                        ],
                        "description": "Function of the discourse marker"
                    }
                },
                "required": ["text", "position", "type", "function"]
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
                                    "description": "Start character position"
                                },
                                "end": {
                                    "type": "integer",
                                    "description": "End character position"
                                }
                            },
                            "required": ["start", "end"]
                        },
                        "role": {
                            "type": "string",
                            "enum": ["antecedent", "consequent", "parallel", "other"],
                            "description": "Role of the segment in relation to the marker"
                        }
                    },
                    "required": ["text", "position", "role"]
                },
                "minItems": 2,
                "description": "Text segments connected by the discourse marker"
            },
            "coherence_relations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "description": "Type of coherence relation"
                        },
                        "segments": {
                            "type": "array",
                            "items": {
                                "type": "integer",
                                "description": "Index of segment in segments array"
                            },
                            "minItems": 2
                        },
                        "strength": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Strength of the coherence relation"
                        }
                    },
                    "required": ["type", "segments"]
                }
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
                        "description": "ID of the paragraph containing the marker"
                    },
                    "sentence_id": {
                        "type": "string",
                        "description": "ID of the sentence containing the marker"
                    },
                    "genre": {
                        "type": "string",
                        "description": "Genre or type of text"
                    },
                    "register": {
                        "type": "string",
                        "description": "Register or formality level"
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
                        "description": "Confidence score"
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