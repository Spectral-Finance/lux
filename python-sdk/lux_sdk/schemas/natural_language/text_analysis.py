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
            "timestamp": {"type": "string", "format": "date-time"},
            "analysis_id": {"type": "string"},
            "text": {
                "type": "object",
                "properties": {
                    "content": {"type": "string"},
                    "language": {"type": "string"},
                    "encoding": {"type": "string"}
                },
                "required": ["content", "language", "encoding"]
            },
            "linguistic_features": {
                "type": "object",
                "properties": {
                    "tokens": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string"},
                                "pos": {"type": "string"},  # Part of speech
                                "lemma": {"type": "string"},
                                "start": {"type": "integer"},
                                "end": {"type": "integer"}
                            },
                            "required": ["text", "pos", "lemma", "start", "end"]
                        }
                    },
                    "sentences": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string"},
                                "start": {"type": "integer"},
                                "end": {"type": "integer"}
                            },
                            "required": ["text", "start", "end"]
                        }
                    },
                    "named_entities": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string"},
                                "type": {"type": "string"},
                                "start": {"type": "integer"},
                                "end": {"type": "integer"},
                                "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0}
                            },
                            "required": ["text", "type", "start", "end"]
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
                                "name": {"type": "string"},
                                "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0},
                                "keywords": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["name", "confidence"]
                        }
                    },
                    "intent": {
                        "type": "object",
                        "properties": {
                            "type": {"type": "string"},
                            "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0}
                        },
                        "required": ["type", "confidence"]
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
        },
        "required": ["timestamp", "analysis_id", "text", "linguistic_features"]
    }
) 