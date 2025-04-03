from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class LanguageModelOutputSchema(SignalSchema):
    """Schema for representing language model generation outputs.
    
    This schema defines the structure for outputs from language models,
    including the generated text, confidence scores, and generation metadata.
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "output_id": "lmo-123456",
            "model_id": "gpt-4",
            "generated_text": {
                "content": "The quick brown fox jumps over the lazy dog.",
                "format": "plain_text",
                "language": "en"
            },
            "confidence_scores": {
                "overall": 0.95,
                "per_token": [0.98, 0.97, 0.96]
            },
            "generation_params": {
                "temperature": 0.7,
                "top_p": 0.9,
                "max_tokens": 100
            },
            "metadata": {
                "prompt_tokens": 10,
                "completion_tokens": 9,
                "total_tokens": 19,
                "generation_time_ms": 234
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="language_model_output",
            version="1.0",
            description="Schema for language model generation outputs",
            schema={
                "type": "object",
                "required": ["timestamp", "output_id", "model_id", "generated_text"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the output was generated"
                    },
                    "output_id": {
                        "type": "string",
                        "description": "Unique identifier for this output"
                    },
                    "model_id": {
                        "type": "string",
                        "description": "Identifier of the language model used"
                    },
                    "generated_text": {
                        "type": "object",
                        "required": ["content", "format", "language"],
                        "properties": {
                            "content": {
                                "type": "string",
                                "description": "The actual generated text"
                            },
                            "format": {
                                "type": "string",
                                "enum": ["plain_text", "markdown", "html", "json"],
                                "description": "Format of the generated content"
                            },
                            "language": {
                                "type": "string",
                                "description": "ISO 639-1 language code"
                            }
                        }
                    },
                    "confidence_scores": {
                        "type": "object",
                        "properties": {
                            "overall": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Overall confidence score for the generation"
                            },
                            "per_token": {
                                "type": "array",
                                "items": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1
                                },
                                "description": "Confidence scores for each token"
                            }
                        }
                    },
                    "generation_params": {
                        "type": "object",
                        "properties": {
                            "temperature": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Sampling temperature used"
                            },
                            "top_p": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Top-p sampling parameter"
                            },
                            "max_tokens": {
                                "type": "integer",
                                "minimum": 1,
                                "description": "Maximum tokens to generate"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "prompt_tokens": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Number of tokens in the prompt"
                            },
                            "completion_tokens": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Number of tokens in the completion"
                            },
                            "total_tokens": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Total number of tokens"
                            },
                            "generation_time_ms": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Generation time in milliseconds"
                            }
                        }
                    }
                }
            }
        ) 