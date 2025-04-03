"""
LanguageModel Schema

This schema defines the structure for representing language model configurations,
capabilities, and operational parameters.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "model_id": "gpt4_0314",
    "capabilities": {
        "tasks": ["text_generation", "chat", "summarization"],
        "languages": ["en", "es", "fr"],
        "max_tokens": 8192,
        "streaming": true
    },
    "configuration": {
        "temperature": 0.7,
        "top_p": 0.95,
        "frequency_penalty": 0.0,
        "presence_penalty": 0.0,
        "stop_sequences": ["\n\n", "###"]
    },
    "performance": {
        "latency": {
            "average_ms": 250,
            "p95_ms": 500,
            "p99_ms": 750
        },
        "throughput": {
            "tokens_per_second": 100,
            "requests_per_minute": 600
        },
        "quality_metrics": {
            "accuracy": 0.92,
            "consistency": 0.88,
            "toxicity_rate": 0.01
        }
    },
    "metadata": {
        "provider": "openai",
        "version": "1.0",
        "last_updated": "2024-03-20T15:30:00Z",
        "status": "active"
    }
}
```
"""

from lux_sdk.signals import SignalSchema

LanguageModelSchema = SignalSchema(
    name="language_model",
    version="1.0",
    description="Schema for representing language model configurations and capabilities",
    schema={
        "type": "object",
        "required": ["timestamp", "model_id", "capabilities", "configuration", "metadata"],
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "Configuration timestamp"
            },
            "model_id": {
                "type": "string",
                "description": "Unique model identifier"
            },
            "capabilities": {
                "type": "object",
                "required": ["tasks", "languages", "max_tokens"],
                "properties": {
                    "tasks": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Supported tasks"
                    },
                    "languages": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Supported languages"
                    },
                    "max_tokens": {
                        "type": "integer",
                        "minimum": 1,
                        "description": "Maximum context length"
                    },
                    "streaming": {
                        "type": "boolean",
                        "description": "Streaming capability"
                    }
                }
            },
            "configuration": {
                "type": "object",
                "properties": {
                    "temperature": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 2,
                        "description": "Sampling temperature"
                    },
                    "top_p": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Nucleus sampling threshold"
                    },
                    "frequency_penalty": {
                        "type": "number",
                        "minimum": -2,
                        "maximum": 2,
                        "description": "Frequency penalty"
                    },
                    "presence_penalty": {
                        "type": "number",
                        "minimum": -2,
                        "maximum": 2,
                        "description": "Presence penalty"
                    },
                    "stop_sequences": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Stop sequences"
                    }
                }
            },
            "performance": {
                "type": "object",
                "properties": {
                    "latency": {
                        "type": "object",
                        "properties": {
                            "average_ms": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Average latency"
                            },
                            "p95_ms": {
                                "type": "number",
                                "minimum": 0,
                                "description": "95th percentile latency"
                            },
                            "p99_ms": {
                                "type": "number",
                                "minimum": 0,
                                "description": "99th percentile latency"
                            }
                        }
                    },
                    "throughput": {
                        "type": "object",
                        "properties": {
                            "tokens_per_second": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Token processing rate"
                            },
                            "requests_per_minute": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Request processing rate"
                            }
                        }
                    },
                    "quality_metrics": {
                        "type": "object",
                        "properties": {
                            "accuracy": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Model accuracy"
                            },
                            "consistency": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Output consistency"
                            },
                            "toxicity_rate": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Toxicity rate"
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "required": ["provider", "version", "status"],
                "properties": {
                    "provider": {
                        "type": "string",
                        "description": "Model provider"
                    },
                    "version": {
                        "type": "string",
                        "description": "Model version"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update time"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["active", "deprecated", "maintenance"],
                        "description": "Model status"
                    }
                }
            }
        },
        "additionalProperties": False
    }
) 