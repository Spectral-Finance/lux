"""
Schema for representing translation requests and requirements.

This schema defines the structure for documenting and managing translation requests,
including source text, target requirements, quality assurance, and metadata.

Example:
    {
        "timestamp": "2024-04-03T15:30:00Z",
        "request_id": "tr_123",
        "requester_id": "user_456",
        "source": {
            "text": "Hello world",
            "language": "en",
            "dialect": "en-US",
            "format": "markdown",
            "context": "software documentation"
        },
        "target": {
            "language": "es",
            "dialect": "es-ES",
            "format": "markdown",
            "preserve_formatting": true,
            "style_guide": "spanish_tech_guide"
        },
        "requirements": {
            "quality_level": "professional",
            "tone": "technical",
            "formality": "formal",
            "audience": "developers",
            "purpose": "software localization",
            "special_instructions": [
                "Maintain technical terminology",
                "Keep code snippets unchanged"
            ]
        },
        "terminology": {
            "glossary_refs": ["tech_glossary_v1"],
            "term_preferences": [{
                "source_term": "repository",
                "target_term": "repositorio",
                "context": "version control",
                "notes": "Use in Git context"
            }],
            "forbidden_terms": ["repo"]
        },
        "reference_materials": [{
            "type": "style_guide",
            "url": "https://example.com/style_guide",
            "description": "Company style guide",
            "relevance": "Primary reference"
        }],
        "quality_assurance": {
            "review_type": "peer_review",
            "reviewers": ["reviewer_123"],
            "quality_metrics": [{
                "metric": "accuracy",
                "threshold": 0.95,
                "weight": 0.6
            }],
            "validation_steps": [
                "terminology_check",
                "grammar_check"
            ]
        },
        "metadata": {
            "created_at": "2024-04-03T15:30:00Z",
            "due_date": "2024-04-10T15:30:00Z",
            "priority": "high",
            "project_id": "proj_789",
            "budget_code": "trans_2024_q2",
            "tags": ["technical", "software", "localization"]
        }
    }
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class TranslationRequestSchema(SignalSchema):
    def __init__(self):
        super().__init__(
            name="translation_request",
            version="1.0",
            description="Schema for representing translation requests and their specifications",
            schema={
                "type": "object",
                "required": ["timestamp", "request_id", "requester_id", "source", "target"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the translation request"
                    },
                    "request_id": {
                        "type": "string",
                        "description": "Unique identifier for the translation request"
                    },
                    "requester_id": {
                        "type": "string",
                        "description": "Identifier of the translation requester"
                    },
                    "source": {
                        "type": "object",
                        "description": "Source text information",
                        "required": ["text", "language"],
                        "properties": {
                            "text": {
                                "type": "string",
                                "description": "Text to be translated"
                            },
                            "language": {
                                "type": "string",
                                "description": "Source language code (ISO 639-1)"
                            },
                            "dialect": {
                                "type": "string",
                                "description": "Specific dialect or variant"
                            },
                            "format": {
                                "type": "string",
                                "description": "Format of the source text (e.g., plain, html, markdown)"
                            },
                            "context": {
                                "type": "string",
                                "description": "Context or domain of the text"
                            }
                        }
                    },
                    "target": {
                        "type": "object",
                        "description": "Target translation requirements",
                        "required": ["language"],
                        "properties": {
                            "language": {
                                "type": "string",
                                "description": "Target language code (ISO 639-1)"
                            },
                            "dialect": {
                                "type": "string",
                                "description": "Required dialect or variant"
                            },
                            "format": {
                                "type": "string",
                                "description": "Required output format"
                            },
                            "preserve_formatting": {
                                "type": "boolean",
                                "description": "Whether to preserve original formatting"
                            },
                            "style_guide": {
                                "type": "string",
                                "description": "Reference to style guide to follow"
                            }
                        }
                    },
                    "requirements": {
                        "type": "object",
                        "description": "Translation requirements and preferences",
                        "properties": {
                            "quality_level": {
                                "type": "string",
                                "description": "Required quality level"
                            },
                            "tone": {
                                "type": "string",
                                "description": "Required tone of translation"
                            },
                            "formality": {
                                "type": "string",
                                "description": "Level of formality"
                            },
                            "audience": {
                                "type": "string",
                                "description": "Target audience"
                            },
                            "purpose": {
                                "type": "string",
                                "description": "Purpose of the translation"
                            },
                            "special_instructions": {
                                "type": "array",
                                "description": "Special handling instructions",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "terminology": {
                        "type": "object",
                        "description": "Terminology management",
                        "properties": {
                            "glossary_refs": {
                                "type": "array",
                                "description": "References to terminology glossaries",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "term_preferences": {
                                "type": "array",
                                "description": "Preferred term translations",
                                "items": {
                                    "type": "object",
                                    "required": ["source_term", "target_term"],
                                    "properties": {
                                        "source_term": {
                                            "type": "string",
                                            "description": "Term in source language"
                                        },
                                        "target_term": {
                                            "type": "string",
                                            "description": "Preferred translation"
                                        },
                                        "context": {
                                            "type": "string",
                                            "description": "Usage context"
                                        },
                                        "notes": {
                                            "type": "string",
                                            "description": "Usage notes"
                                        }
                                    }
                                }
                            },
                            "forbidden_terms": {
                                "type": "array",
                                "description": "Terms not to be used",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "reference_materials": {
                        "type": "array",
                        "description": "Reference materials for translation",
                        "items": {
                            "type": "object",
                            "required": ["type", "description"],
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of reference material"
                                },
                                "url": {
                                    "type": "string",
                                    "description": "URL or location of the material"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the material"
                                },
                                "relevance": {
                                    "type": "string",
                                    "description": "Relevance to the translation"
                                }
                            }
                        }
                    },
                    "quality_assurance": {
                        "type": "object",
                        "description": "Quality assurance requirements",
                        "properties": {
                            "review_type": {
                                "type": "string",
                                "description": "Type of review required"
                            },
                            "reviewers": {
                                "type": "array",
                                "description": "Required reviewers",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "quality_metrics": {
                                "type": "array",
                                "description": "Quality metrics to be met",
                                "items": {
                                    "type": "object",
                                    "required": ["metric", "threshold"],
                                    "properties": {
                                        "metric": {
                                            "type": "string",
                                            "description": "Name of the metric"
                                        },
                                        "threshold": {
                                            "type": "number",
                                            "description": "Required threshold"
                                        },
                                        "weight": {
                                            "type": "number",
                                            "description": "Importance weight"
                                        }
                                    }
                                }
                            },
                            "validation_steps": {
                                "type": "array",
                                "description": "Required validation steps",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the translation request",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "due_date": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Required completion date"
                            },
                            "priority": {
                                "type": "string",
                                "description": "Request priority"
                            },
                            "project_id": {
                                "type": "string",
                                "description": "Associated project identifier"
                            },
                            "budget_code": {
                                "type": "string",
                                "description": "Budget or billing code"
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