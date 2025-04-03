"""
SentimentAnalysisSchema

This schema represents the results of sentiment analysis on text or other content,
including polarity, subjectivity, and emotional components.
"""

from lux_sdk.signals import SignalSchema

SentimentAnalysisSchema = SignalSchema(
    name="sentiment_analysis",
    version="1.0",
    description="Schema for representing sentiment analysis results on text or other content",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "analysis_id": {"type": "string", "required": True},
            "content": {
                "type": "object",
                "required": True,
                "properties": {
                    "text": {"type": "string", "required": True},
                    "source": {"type": "string", "required": True},
                    "context": {"type": "string"}
                }
            },
            "sentiment": {
                "type": "object",
                "required": True,
                "properties": {
                    "polarity": {
                        "type": "number",
                        "minimum": -1.0,
                        "maximum": 1.0,
                        "required": True,
                        "description": "Sentiment polarity from -1.0 (negative) to 1.0 (positive)"
                    },
                    "subjectivity": {
                        "type": "number",
                        "minimum": 0.0,
                        "maximum": 1.0,
                        "required": True,
                        "description": "Subjectivity level from 0.0 (objective) to 1.0 (subjective)"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0.0,
                        "maximum": 1.0,
                        "required": True
                    }
                }
            },
            "emotions": {
                "type": "object",
                "required": True,
                "properties": {
                    "joy": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True},
                    "sadness": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True},
                    "anger": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True},
                    "fear": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True},
                    "surprise": {"type": "number", "minimum": 0.0, "maximum": 1.0, "required": True}
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "language": {"type": "string"},
                    "model_version": {"type": "string"},
                    "processing_time": {"type": "number"},
                    "tags": {"type": "array", "items": {"type": "string"}}
                }
            }
        }
    }
) 