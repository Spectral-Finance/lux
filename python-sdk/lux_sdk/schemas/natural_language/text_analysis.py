"""
TextAnalysisSchema

This schema represents the results of text analysis operations,
including linguistic features, semantic analysis, and structural properties.
"""

from lux_sdk.signals import SignalSchema

TextAnalysisSchema = SignalSchema(
    name="text_analysis",
    version="1.0",
    description="Schema for representing text analysis results including linguistic features and semantic analysis",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "analysis_id": {"type": "string", "required": True},
            "text": {
                "type": "object",
                "required": True,
                "properties": {
                    "content": {"type": "string", "required": True},
                    "language": {"type": "string", "required": True},
                    "encoding": {"type": "string", "required": True}
                }
            },
            "linguistic_features": {
                "type": "object",
                "required": True,
                "properties": {
                    "tokens": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string", "required": True},
                                "pos": {"type": "string", "required": True},  # Part of speech
                                "lemma": {"type": "string", "required": True},
                                "start": {"type": "integer", "required": True},
                                "end": {"type": "integer", "required": True}
                            }
                        }
                    },
                    "sentences": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string", "required": True},
                                "start": {"type": "integer", "required": True},
                                "end": {"type": "integer", "required": True}
                            }
                        }
                    },
                    "named_entities": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string", "required": True},
                                "type": {"type": "string", "required": True},
                                "start": {"type": "integer", "required": True},
                                "end": {"type": "integer", "required": True},
                                "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0}
                            }
                        }
                    }
                }
            },
            "semantic_analysis": {
                "type": "object",
                "properties": {
                    "topics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True},
                                "keywords": {"type": "array", "items": {"type": "string"}}
                            }
                        }
                    },
                    "intent": {
                        "type": "object",
                        "properties": {
                            "type": {"type": "string", "required": True},
                            "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True}
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "model_version": {"type": "string"},
                    "processing_time": {"type": "number"},
                    "analysis_type": {"type": "string"},
                    "tags": {"type": "array", "items": {"type": "string"}}
                }
            }
        }
    }
) 