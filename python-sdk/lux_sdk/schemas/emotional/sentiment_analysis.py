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
            "timestamp": {"type": "string", "format": "date-time"},
            "analysis_id": {"type": "string"},
            "content": {
                "type": "object",
                "properties": {
                    "text": {"type": "string"},
                    "source": {"type": "string"},
                    "context": {"type": "string"}
                },
                "required": ["text", "source"]
            },
            "sentiment": {
                "type": "object",
                "properties": {
                    "polarity": {
                        "type": "number",
                        "minimum": -1.0,
                        "maximum": 1.0,
                        "description": "Sentiment polarity from -1.0 (negative) to 1.0 (positive)"
                    },
                    "subjectivity": {
                        "type": "number",
                        "minimum": 0.0,
                        "maximum": 1.0,
                        "description": "Subjectivity level from 0.0 (objective) to 1.0 (subjective)"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0.0,
                        "maximum": 1.0
                    }
                },
                "required": ["polarity", "subjectivity", "confidence"]
            },
            "emotions": {
                "type": "object",
                "properties": {
                    "joy": {"type": "number", "minimum": 0.0, "maximum": 1.0},
                    "sadness": {"type": "number", "minimum": 0.0, "maximum": 1.0},
                    "anger": {"type": "number", "minimum": 0.0, "maximum": 1.0},
                    "fear": {"type": "number", "minimum": 0.0, "maximum": 1.0},
                    "surprise": {"type": "number", "minimum": 0.0, "maximum": 1.0}
                },
                "required": ["joy", "sadness", "anger", "fear", "surprise"]
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
        },
        "required": ["timestamp", "analysis_id", "content", "sentiment", "emotions"]
    }
) 