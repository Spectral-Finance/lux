from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class TranslationRequestSchema(SignalSchema):
    """Schema for representing translation requests and requirements.
    
    This schema defines the structure for translation requests, including source
    content, target languages, translation requirements, and quality metrics.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "request_id": "trans_20240403_153000",
            "project_id": "project_789",
            "source_content": {
                "text": "Welcome to our platform",
                "language": "en",
                "format": "plain_text",
                "context": "website_header",
                "word_count": 4,
                "character_count": 23
            },
            "target_languages": [{
                "language_code": "es",
                "locale": "es_MX",
                "script": "Latin",
                "direction": "ltr"
            }, {
                "language_code": "fr",
                "locale": "fr_FR",
                "script": "Latin",
                "direction": "ltr"
            }],
            "requirements": {
                "quality_level": "professional",
                "tone": "formal",
                "domain": "technology",
                "preserve_formatting": true,
                "handle_placeholders": true,
                "terminology": {
                    "glossary_id": "tech_glossary_123",
                    "enforce_strict": true,
                    "custom_terms": {
                        "platform": {
                            "es": "plataforma",
                            "fr": "plateforme"
                        }
                    }
                }
            },
            "style_guide": {
                "guide_id": "style_123",
                "brand_voice": "professional_friendly",
                "language_preferences": {
                    "use_formal_pronouns": true,
                    "use_active_voice": true,
                    "avoid_colloquialisms": true
                },
                "formatting_rules": {
                    "date_format": "DD/MM/YYYY",
                    "number_format": "1.234,56",
                    "currency_format": "€#.###,##"
                }
            },
            "quality_assurance": {
                "required_checks": [
                    "spelling",
                    "grammar",
                    "terminology",
                    "consistency"
                ],
                "review_type": "expert_review",
                "acceptance_criteria": {
                    "minimum_score": 0.95,
                    "error_threshold": 0.02,
                    "required_reviewers": 2
                }
            },
            "delivery": {
                "deadline": "2024-04-04T15:30:00Z",
                "format": "json",
                "notification_email": "project@example.com",
                "callback_url": "https://api.example.com/callback"
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "translation_manager",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "priority": "normal",
                "tags": ["website", "header", "marketing"],
                "notes": "Please maintain brand voice across translations"
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="translation_request",
            version="1.0",
            description="Schema for representing translation requests and requirements",
            schema={
                "type": "object",
                "required": ["timestamp", "request_id", "project_id", "source_content", "target_languages"],
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
                    "project_id": {
                        "type": "string",
                        "description": "Identifier of the associated project"
                    },
                    "source_content": {
                        "type": "object",
                        "description": "Content to be translated",
                        "required": ["text", "language"],
                        "properties": {
                            "text": {
                                "type": "string",
                                "description": "Text content to translate"
                            },
                            "language": {
                                "type": "string",
                                "description": "Source language code"
                            },
                            "format": {
                                "type": "string",
                                "enum": ["plain_text", "html", "markdown", "xml"],
                                "description": "Format of the content"
                            },
                            "context": {
                                "type": "string",
                                "description": "Context where the content appears"
                            },
                            "word_count": {
                                "type": "integer",
                                "description": "Number of words in the content"
                            },
                            "character_count": {
                                "type": "integer",
                                "description": "Number of characters in the content"
                            }
                        }
                    },
                    "target_languages": {
                        "type": "array",
                        "description": "Languages to translate into",
                        "items": {
                            "type": "object",
                            "required": ["language_code"],
                            "properties": {
                                "language_code": {
                                    "type": "string",
                                    "description": "Target language code"
                                },
                                "locale": {
                                    "type": "string",
                                    "description": "Specific locale for the language"
                                },
                                "script": {
                                    "type": "string",
                                    "description": "Writing script for the language"
                                },
                                "direction": {
                                    "type": "string",
                                    "enum": ["ltr", "rtl"],
                                    "description": "Text direction"
                                }
                            }
                        }
                    },
                    "requirements": {
                        "type": "object",
                        "description": "Translation requirements",
                        "properties": {
                            "quality_level": {
                                "type": "string",
                                "enum": ["draft", "professional", "expert", "native"],
                                "description": "Required quality level"
                            },
                            "tone": {
                                "type": "string",
                                "enum": ["formal", "informal", "technical", "casual"],
                                "description": "Tone of the translation"
                            },
                            "domain": {
                                "type": "string",
                                "description": "Subject domain of the content"
                            },
                            "preserve_formatting": {
                                "type": "boolean",
                                "description": "Whether to preserve original formatting"
                            },
                            "handle_placeholders": {
                                "type": "boolean",
                                "description": "Whether to handle placeholders"
                            },
                            "terminology": {
                                "type": "object",
                                "description": "Terminology requirements",
                                "properties": {
                                    "glossary_id": {
                                        "type": "string",
                                        "description": "ID of the terminology glossary"
                                    },
                                    "enforce_strict": {
                                        "type": "boolean",
                                        "description": "Whether to strictly enforce terminology"
                                    },
                                    "custom_terms": {
                                        "type": "object",
                                        "description": "Custom terminology mappings",
                                        "additionalProperties": {
                                            "type": "object",
                                            "additionalProperties": {
                                                "type": "string"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "style_guide": {
                        "type": "object",
                        "description": "Style guide requirements",
                        "properties": {
                            "guide_id": {
                                "type": "string",
                                "description": "ID of the style guide"
                            },
                            "brand_voice": {
                                "type": "string",
                                "description": "Brand voice characteristics"
                            },
                            "language_preferences": {
                                "type": "object",
                                "description": "Language-specific preferences",
                                "properties": {
                                    "use_formal_pronouns": {
                                        "type": "boolean",
                                        "description": "Whether to use formal pronouns"
                                    },
                                    "use_active_voice": {
                                        "type": "boolean",
                                        "description": "Whether to use active voice"
                                    },
                                    "avoid_colloquialisms": {
                                        "type": "boolean",
                                        "description": "Whether to avoid colloquialisms"
                                    }
                                }
                            },
                            "formatting_rules": {
                                "type": "object",
                                "description": "Formatting rules",
                                "properties": {
                                    "date_format": {
                                        "type": "string",
                                        "description": "Date format pattern"
                                    },
                                    "number_format": {
                                        "type": "string",
                                        "description": "Number format pattern"
                                    },
                                    "currency_format": {
                                        "type": "string",
                                        "description": "Currency format pattern"
                                    }
                                }
                            }
                        }
                    },
                    "quality_assurance": {
                        "type": "object",
                        "description": "Quality assurance requirements",
                        "properties": {
                            "required_checks": {
                                "type": "array",
                                "description": "Required quality checks",
                                "items": {
                                    "type": "string",
                                    "enum": [
                                        "spelling",
                                        "grammar",
                                        "terminology",
                                        "consistency",
                                        "style",
                                        "formatting"
                                    ]
                                }
                            },
                            "review_type": {
                                "type": "string",
                                "enum": ["self_review", "peer_review", "expert_review"],
                                "description": "Type of review required"
                            },
                            "acceptance_criteria": {
                                "type": "object",
                                "description": "Acceptance criteria",
                                "properties": {
                                    "minimum_score": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Minimum quality score"
                                    },
                                    "error_threshold": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Maximum error rate"
                                    },
                                    "required_reviewers": {
                                        "type": "integer",
                                        "minimum": 1,
                                        "description": "Number of required reviewers"
                                    }
                                }
                            }
                        }
                    },
                    "delivery": {
                        "type": "object",
                        "description": "Delivery requirements",
                        "properties": {
                            "deadline": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Delivery deadline"
                            },
                            "format": {
                                "type": "string",
                                "enum": ["plain_text", "json", "xml", "html", "xliff"],
                                "description": "Delivery format"
                            },
                            "notification_email": {
                                "type": "string",
                                "format": "email",
                                "description": "Email for notifications"
                            },
                            "callback_url": {
                                "type": "string",
                                "format": "uri",
                                "description": "Callback URL for notifications"
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
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the request"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Request version"
                            },
                            "priority": {
                                "type": "string",
                                "enum": ["low", "normal", "high", "urgent"],
                                "description": "Request priority"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {"type": "string"}
                            },
                            "notes": {
                                "type": "string",
                                "description": "Additional notes"
                            }
                        }
                    }
                }
            }
        ) 