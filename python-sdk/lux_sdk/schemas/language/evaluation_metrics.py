from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class LanguageEvaluationMetricsSchema(SignalSchema):
    """Schema for representing language model evaluation metrics.
    
    This schema defines the structure for various evaluation metrics used to assess
    language model performance, including accuracy, fluency, relevance, and other
    standard NLP metrics.
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "evaluation_id": "eval-123456",
            "model_id": "gpt-4",
            "dataset_id": "test-set-001",
            "task_type": "text_generation",
            "metrics": {
                "accuracy": {
                    "exact_match": 0.85,
                    "f1_score": 0.92,
                    "precision": 0.94,
                    "recall": 0.90
                },
                "fluency": {
                    "perplexity": 12.5,
                    "grammar_score": 0.95
                },
                "relevance": {
                    "semantic_similarity": 0.88,
                    "topic_relevance": 0.92
                },
                "diversity": {
                    "distinct_1": 0.75,
                    "distinct_2": 0.85,
                    "unique_tokens_ratio": 0.65
                }
            },
            "per_category_scores": [
                {
                    "category": "technical",
                    "accuracy": 0.92,
                    "sample_count": 100
                }
            ],
            "metadata": {
                "evaluation_time": "2024-04-03T12:34:56Z",
                "evaluator_version": "1.0.0",
                "sample_size": 1000
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="language_evaluation_metrics",
            version="1.0",
            description="Schema for language model evaluation metrics",
            schema={
                "type": "object",
                "required": ["timestamp", "evaluation_id", "model_id", "task_type", "metrics"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the evaluation was performed"
                    },
                    "evaluation_id": {
                        "type": "string",
                        "description": "Unique identifier for this evaluation"
                    },
                    "model_id": {
                        "type": "string",
                        "description": "Identifier of the language model evaluated"
                    },
                    "dataset_id": {
                        "type": "string",
                        "description": "Identifier of the evaluation dataset"
                    },
                    "task_type": {
                        "type": "string",
                        "enum": [
                            "text_generation",
                            "translation",
                            "summarization",
                            "question_answering",
                            "classification",
                            "other"
                        ],
                        "description": "Type of language task being evaluated"
                    },
                    "metrics": {
                        "type": "object",
                        "properties": {
                            "accuracy": {
                                "type": "object",
                                "properties": {
                                    "exact_match": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Exact match accuracy"
                                    },
                                    "f1_score": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "F1 score"
                                    },
                                    "precision": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Precision score"
                                    },
                                    "recall": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Recall score"
                                    }
                                }
                            },
                            "fluency": {
                                "type": "object",
                                "properties": {
                                    "perplexity": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Model perplexity score"
                                    },
                                    "grammar_score": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Grammar correctness score"
                                    }
                                }
                            },
                            "relevance": {
                                "type": "object",
                                "properties": {
                                    "semantic_similarity": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Semantic similarity score"
                                    },
                                    "topic_relevance": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Topic relevance score"
                                    }
                                }
                            },
                            "diversity": {
                                "type": "object",
                                "properties": {
                                    "distinct_1": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Ratio of distinct unigrams"
                                    },
                                    "distinct_2": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Ratio of distinct bigrams"
                                    },
                                    "unique_tokens_ratio": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Ratio of unique tokens"
                                    }
                                }
                            }
                        }
                    },
                    "per_category_scores": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["category", "accuracy", "sample_count"],
                            "properties": {
                                "category": {
                                    "type": "string",
                                    "description": "Category name"
                                },
                                "accuracy": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Accuracy score for this category"
                                },
                                "sample_count": {
                                    "type": "integer",
                                    "minimum": 1,
                                    "description": "Number of samples in this category"
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "evaluation_time": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When the evaluation was performed"
                            },
                            "evaluator_version": {
                                "type": "string",
                                "description": "Version of the evaluation system"
                            },
                            "sample_size": {
                                "type": "integer",
                                "minimum": 1,
                                "description": "Total number of samples evaluated"
                            }
                        }
                    }
                }
            }
        ) 