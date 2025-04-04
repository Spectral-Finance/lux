"""
Paraphrase Schema

This schema represents paraphrase generation and analysis,
including input text, generated alternatives, and semantic preservation metrics.
"""

from lux_sdk.signals import SignalSchema

ParaphraseSchema = SignalSchema(
    name="paraphrase",
    version="1.0",
    description="Schema for paraphrase generation and analysis",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "paraphrase_id": {
                "type": "string",
                "description": "Unique identifier for this paraphrase"
            },
            "source_text": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "Original text to paraphrase"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language of the text"
                    },
                    "context": {
                        "type": "string",
                        "description": "Context in which the text appears"
                    },
                    "key_phrases": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Important phrases to preserve"
                        }
                    }
                },
                "required": ["text", "language"]
            },
            "paraphrase_options": {
                "type": "object",
                "properties": {
                    "style": {
                        "type": "string",
                        "enum": ["formal", "informal", "technical", "simplified", "creative"],
                        "description": "Desired style of paraphrase"
                    },
                    "constraints": {
                        "type": "object",
                        "properties": {
                            "max_length": {
                                "type": "integer",
                                "description": "Maximum length in characters"
                            },
                            "preserve_keywords": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "Keywords to preserve"
                                }
                            },
                            "readability_level": {
                                "type": "string",
                                "enum": ["elementary", "intermediate", "advanced", "expert"],
                                "description": "Target readability level"
                            }
                        }
                    },
                    "transformation_type": {
                        "type": "string",
                        "enum": ["lexical", "syntactic", "semantic", "mixed"],
                        "description": "Type of transformation to apply"
                    }
                }
            },
            "generated_paraphrases": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "Paraphrased text"
                        },
                        "transformation_applied": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "description": "Type of transformation"
                                    },
                                    "original_segment": {
                                        "type": "string",
                                        "description": "Original text segment"
                                    },
                                    "transformed_segment": {
                                        "type": "string",
                                        "description": "Transformed text segment"
                                    },
                                    "rationale": {
                                        "type": "string",
                                        "description": "Reason for transformation"
                                    }
                                }
                            }
                        },
                        "quality_metrics": {
                            "type": "object",
                            "properties": {
                                "semantic_similarity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Semantic similarity score"
                                },
                                "fluency": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Fluency score"
                                },
                                "diversity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Lexical diversity score"
                                },
                                "style_match": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Style matching score"
                                }
                            }
                        }
                    },
                    "required": ["text"]
                }
            },
            "validation": {
                "type": "object",
                "properties": {
                    "meaning_preservation": {
                        "type": "object",
                        "properties": {
                            "score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Meaning preservation score"
                            },
                            "issues": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "Identified meaning issues"
                                }
                            }
                        }
                    },
                    "grammaticality": {
                        "type": "object",
                        "properties": {
                            "score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Grammaticality score"
                            },
                            "errors": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "description": "Type of error"
                                        },
                                        "description": {
                                            "type": "string",
                                            "description": "Error description"
                                        },
                                        "suggestion": {
                                            "type": "string",
                                            "description": "Suggested correction"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "model_version": {
                        "type": "string",
                        "description": "Version of the paraphrase model"
                    },
                    "generation_timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When paraphrases were generated"
                    },
                    "processing_time": {
                        "type": "number",
                        "description": "Time taken to generate in milliseconds"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "paraphrase_id",
            "source_text",
            "generated_paraphrases"
        ]
    }
) 