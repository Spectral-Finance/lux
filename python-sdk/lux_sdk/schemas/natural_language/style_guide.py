"""
Style Guide Schema

This schema represents style guides and writing conventions,
including formatting rules, language preferences, and content guidelines.
"""

from lux_sdk.signals import SignalSchema

StyleGuideSchema = SignalSchema(
    name="style_guide",
    version="1.0",
    description="Schema for style guides and writing conventions",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "guide_id": {
                "type": "string",
                "description": "Unique identifier for this style guide"
            },
            "name": {
                "type": "string",
                "description": "Name of the style guide"
            },
            "description": {
                "type": "string",
                "description": "Description of the style guide's purpose and scope"
            },
            "language_settings": {
                "type": "object",
                "properties": {
                    "primary_language": {
                        "type": "string",
                        "description": "Primary language for content"
                    },
                    "supported_languages": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Additional supported languages"
                    },
                    "locale_preferences": {
                        "type": "object",
                        "properties": {
                            "region": {
                                "type": "string",
                                "description": "Target region or market"
                            },
                            "date_format": {
                                "type": "string",
                                "description": "Preferred date format"
                            },
                            "time_format": {
                                "type": "string",
                                "description": "Preferred time format"
                            },
                            "number_format": {
                                "type": "string",
                                "description": "Preferred number format"
                            }
                        }
                    }
                },
                "required": ["primary_language"]
            },
            "formatting_rules": {
                "type": "object",
                "properties": {
                    "capitalization": {
                        "type": "object",
                        "properties": {
                            "titles": {
                                "type": "string",
                                "enum": ["sentence_case", "title_case", "all_caps", "custom"],
                                "description": "Capitalization style for titles"
                            },
                            "headings": {
                                "type": "string",
                                "enum": ["sentence_case", "title_case", "all_caps", "custom"],
                                "description": "Capitalization style for headings"
                            },
                            "custom_rules": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Custom capitalization rules"
                            }
                        }
                    },
                    "punctuation": {
                        "type": "object",
                        "properties": {
                            "serial_comma": {
                                "type": "boolean",
                                "description": "Use of serial (Oxford) comma"
                            },
                            "quotation_marks": {
                                "type": "string",
                                "enum": ["double", "single"],
                                "description": "Preferred quotation mark style"
                            },
                            "list_punctuation": {
                                "type": "string",
                                "description": "Punctuation style for lists"
                            }
                        }
                    },
                    "spacing": {
                        "type": "object",
                        "properties": {
                            "sentence_spacing": {
                                "type": "integer",
                                "description": "Number of spaces between sentences"
                            },
                            "paragraph_spacing": {
                                "type": "string",
                                "description": "Spacing between paragraphs"
                            },
                            "line_spacing": {
                                "type": "number",
                                "description": "Line spacing multiplier"
                            }
                        }
                    }
                }
            },
            "content_guidelines": {
                "type": "object",
                "properties": {
                    "tone": {
                        "type": "string",
                        "enum": ["formal", "informal", "technical", "conversational", "professional"],
                        "description": "Overall tone of content"
                    },
                    "voice": {
                        "type": "string",
                        "enum": ["active", "passive", "mixed"],
                        "description": "Preferred voice"
                    },
                    "word_choice": {
                        "type": "object",
                        "properties": {
                            "preferred_terms": {
                                "type": "object",
                                "additionalProperties": {
                                    "type": "string"
                                },
                                "description": "Dictionary of preferred terms and their usage"
                            },
                            "avoided_terms": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Terms to avoid"
                            },
                            "abbreviations": {
                                "type": "object",
                                "additionalProperties": {
                                    "type": "string"
                                },
                                "description": "Approved abbreviations and their full forms"
                            }
                        }
                    },
                    "content_structure": {
                        "type": "object",
                        "properties": {
                            "paragraph_length": {
                                "type": "object",
                                "properties": {
                                    "max_sentences": {
                                        "type": "integer",
                                        "description": "Maximum sentences per paragraph"
                                    },
                                    "recommended_length": {
                                        "type": "string",
                                        "description": "Recommended paragraph length"
                                    }
                                }
                            },
                            "sentence_length": {
                                "type": "object",
                                "properties": {
                                    "max_words": {
                                        "type": "integer",
                                        "description": "Maximum words per sentence"
                                    },
                                    "recommended_length": {
                                        "type": "string",
                                        "description": "Recommended sentence length"
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "accessibility_guidelines": {
                "type": "object",
                "properties": {
                    "readability_level": {
                        "type": "string",
                        "description": "Target readability level"
                    },
                    "alt_text_requirements": {
                        "type": "object",
                        "properties": {
                            "required": {
                                "type": "boolean",
                                "description": "Whether alt text is required"
                            },
                            "guidelines": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Guidelines for writing alt text"
                            }
                        }
                    },
                    "color_contrast": {
                        "type": "object",
                        "properties": {
                            "minimum_ratio": {
                                "type": "number",
                                "description": "Minimum contrast ratio"
                            },
                            "preferred_ratio": {
                                "type": "number",
                                "description": "Preferred contrast ratio"
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "version": {
                        "type": "string",
                        "description": "Version of the style guide"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "owner": {
                        "type": "string",
                        "description": "Owner or maintainer of the style guide"
                    },
                    "reviewers": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "List of reviewers"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "deprecated"],
                        "description": "Current status of the style guide"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "guide_id",
            "name",
            "language_settings",
            "content_guidelines"
        ]
    }
) 