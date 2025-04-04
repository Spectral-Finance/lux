"""
Schema for natural language generation tasks and outputs.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class LanguageGenerationSchema(SignalSchema):
    """Schema for natural language generation tasks and outputs.
    
    This schema defines the structure for documenting and managing natural language
    generation tasks, including input parameters, generation settings, outputs,
    and various quality and performance metrics.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "generation_id": "gen_123",
            "task_type": "text_completion",
            "input": {
                "prompt": "Write a product description for a smart watch",
                "constraints": [
                    "Maximum 200 words",
                    "Focus on health features"
                ],
                "style_guide": {
                    "tone": "professional",
                    "formality": "moderate",
                    "language_level": "general"
                },
                "target_audience": "health-conscious professionals"
            },
            "generation_parameters": {
                "model": "gpt-4",
                "temperature": 0.7,
                "max_length": 300,
                "stop_sequences": ["\n\n"],
                "sampling_strategy": "nucleus"
            },
            "output": {
                "text": "Introducing the HealthTech Pro Smartwatch...",
                "tokens": ["Introducing", "the", "HealthTech", "..."],
                "segments": [
                    "Product introduction",
                    "Feature description"
                ],
                "alternatives": [
                    "Meet the revolutionary HealthTech Pro...",
                    "Transform your health journey..."
                ]
            },
            "quality_metrics": {
                "fluency": 0.95,
                "coherence": 0.92,
                "relevance": 0.88,
                "diversity": 0.75,
                "grammar_score": 0.96
            },
            "linguistic_features": {
                "syntax_tree": "(S (NP) (VP) (.))",
                "pos_tags": ["VBG", "DT", "NNP", "..."],
                "entities": ["HealthTech", "Pro", "Smartwatch"],
                "sentiment": {
                    "polarity": 0.6,
                    "subjectivity": 0.3
                }
            },
            "performance_metrics": {
                "generation_time": 2.5,
                "token_count": 150,
                "prompt_tokens": 20,
                "total_tokens": 170
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "updated_at": "2024-04-03T15:30:00Z",
                "user_id": "user_456",
                "version": "1.0",
                "tags": ["product", "description", "health", "tech"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="language_generation",
            version="1.0",
            description="Schema for representing natural language generation tasks and their outputs",
            schema={
                "type": "object",
                "required": ["timestamp", "generation_id", "task_type", "input", "generation_parameters", "output"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the generation task"
                    },
                    "generation_id": {
                        "type": "string",
                        "description": "Unique identifier for the generation task"
                    },
                    "task_type": {
                        "type": "string",
                        "description": "Type of language generation task"
                    },
                    "input": {
                        "type": "object",
                        "description": "Input parameters for generation",
                        "required": ["prompt"],
                        "properties": {
                            "prompt": {
                                "type": "string",
                                "description": "Input prompt or context"
                            },
                            "constraints": {
                                "type": "array",
                                "description": "Generation constraints",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "style_guide": {
                                "type": "object",
                                "description": "Style specifications",
                                "properties": {
                                    "tone": {
                                        "type": "string",
                                        "description": "Desired tone of the output"
                                    },
                                    "formality": {
                                        "type": "string",
                                        "description": "Level of formality"
                                    },
                                    "language_level": {
                                        "type": "string",
                                        "description": "Target language complexity"
                                    }
                                }
                            },
                            "target_audience": {
                                "type": "string",
                                "description": "Intended audience for the output"
                            }
                        }
                    },
                    "generation_parameters": {
                        "type": "object",
                        "description": "Parameters controlling generation",
                        "required": ["model"],
                        "properties": {
                            "model": {
                                "type": "string",
                                "description": "Model used for generation"
                            },
                            "temperature": {
                                "type": "number",
                                "description": "Sampling temperature"
                            },
                            "max_length": {
                                "type": "integer",
                                "description": "Maximum output length"
                            },
                            "stop_sequences": {
                                "type": "array",
                                "description": "Sequences to stop generation",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "sampling_strategy": {
                                "type": "string",
                                "description": "Strategy used for text sampling"
                            }
                        }
                    },
                    "output": {
                        "type": "object",
                        "description": "Generated text output",
                        "required": ["text"],
                        "properties": {
                            "text": {
                                "type": "string",
                                "description": "Generated text content"
                            },
                            "tokens": {
                                "type": "array",
                                "description": "Token-level breakdown",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "segments": {
                                "type": "array",
                                "description": "Logical segments of output",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "alternatives": {
                                "type": "array",
                                "description": "Alternative generations",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "quality_metrics": {
                        "type": "object",
                        "description": "Quality assessment metrics",
                        "properties": {
                            "fluency": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Fluency score (0-1)"
                            },
                            "coherence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Coherence score (0-1)"
                            },
                            "relevance": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Relevance to prompt (0-1)"
                            },
                            "diversity": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Output diversity score (0-1)"
                            },
                            "grammar_score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Grammar quality score (0-1)"
                            }
                        }
                    },
                    "linguistic_features": {
                        "type": "object",
                        "description": "Linguistic analysis of output",
                        "properties": {
                            "syntax_tree": {
                                "type": "string",
                                "description": "Syntactic structure"
                            },
                            "pos_tags": {
                                "type": "array",
                                "description": "Part-of-speech tags",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "entities": {
                                "type": "array",
                                "description": "Named entities",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "sentiment": {
                                "type": "object",
                                "description": "Sentiment analysis",
                                "properties": {
                                    "polarity": {
                                        "type": "number",
                                        "minimum": -1,
                                        "maximum": 1,
                                        "description": "Sentiment polarity (-1 to 1)"
                                    },
                                    "subjectivity": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Subjectivity score (0-1)"
                                    }
                                }
                            }
                        }
                    },
                    "performance_metrics": {
                        "type": "object",
                        "description": "Generation performance metrics",
                        "properties": {
                            "generation_time": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Time taken for generation in seconds"
                            },
                            "token_count": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Number of tokens generated"
                            },
                            "prompt_tokens": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Number of tokens in prompt"
                            },
                            "total_tokens": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Total tokens processed"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the generation task",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "updated_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "user_id": {
                                "type": "string",
                                "description": "ID of the requesting user"
                            },
                            "version": {
                                "type": "string",
                                "description": "Version of the generation system"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    }
                }
            }
        ) 