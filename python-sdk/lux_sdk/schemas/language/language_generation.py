from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class LanguageGenerationSchema(SignalSchema):
    """Schema for representing language generation tasks and requirements.
    
    This schema defines the structure for natural language generation tasks,
    including input parameters, generation requirements, and output specifications.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "task_id": "gen_20240403_153000",
            "project_id": "project_789",
            "input_parameters": {
                "prompt": "Generate a product description for a high-end laptop",
                "context": {
                    "product_type": "laptop",
                    "target_audience": "professionals",
                    "key_features": [
                        "Intel i9 processor",
                        "32GB RAM",
                        "1TB SSD",
                        "4K Display"
                    ],
                    "brand_guidelines": "premium_tech_brand_123",
                    "tone": "professional"
                },
                "references": [{
                    "type": "similar_product",
                    "content": "Previous successful product description",
                    "relevance_score": 0.85
                }],
                "constraints": {
                    "max_length": 500,
                    "min_length": 200,
                    "required_keywords": [
                        "performance",
                        "professional",
                        "premium"
                    ],
                    "forbidden_terms": [
                        "cheap",
                        "budget",
                        "basic"
                    ]
                }
            },
            "generation_requirements": {
                "language": "en",
                "style": {
                    "tone": "professional",
                    "formality": "formal",
                    "creativity_level": 0.7,
                    "persuasion_level": 0.8
                },
                "structure": {
                    "format": "paragraphs",
                    "sections": [
                        "introduction",
                        "features",
                        "benefits",
                        "technical_specs",
                        "conclusion"
                    ],
                    "paragraph_breaks": true,
                    "bullet_points": true
                },
                "seo_requirements": {
                    "target_keywords": [
                        "high-performance laptop",
                        "professional workstation",
                        "premium notebook"
                    ],
                    "keyword_density": 0.02,
                    "meta_description_length": 160
                }
            },
            "quality_requirements": {
                "grammar_check": true,
                "spelling_check": true,
                "readability": {
                    "target_score": 65,
                    "scoring_method": "flesch_kincaid",
                    "target_grade_level": "college"
                },
                "uniqueness": {
                    "min_uniqueness": 0.9,
                    "check_method": "semantic_similarity"
                },
                "brand_compliance": {
                    "voice_guidelines": "brand_voice_123",
                    "terminology": "brand_terms_123",
                    "compliance_level": "strict"
                }
            },
            "output_specifications": {
                "format": "markdown",
                "sections": {
                    "main_content": true,
                    "meta_description": true,
                    "keywords": true,
                    "headers": true
                },
                "variants": {
                    "count": 2,
                    "variation_level": "moderate"
                },
                "metadata": {
                    "include_stats": true,
                    "include_scores": true,
                    "include_keywords": true
                }
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "content_manager",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "priority": "high",
                "tags": ["product", "description", "tech"],
                "notes": "Focus on professional features and performance"
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="language_generation",
            version="1.0",
            description="Schema for representing language generation tasks and requirements",
            schema={
                "type": "object",
                "required": ["timestamp", "task_id", "project_id", "input_parameters", "generation_requirements"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the generation task"
                    },
                    "task_id": {
                        "type": "string",
                        "description": "Unique identifier for the generation task"
                    },
                    "project_id": {
                        "type": "string",
                        "description": "Identifier of the associated project"
                    },
                    "input_parameters": {
                        "type": "object",
                        "description": "Input parameters for generation",
                        "required": ["prompt"],
                        "properties": {
                            "prompt": {
                                "type": "string",
                                "description": "Generation prompt or instruction"
                            },
                            "context": {
                                "type": "object",
                                "description": "Contextual information",
                                "properties": {
                                    "product_type": {
                                        "type": "string",
                                        "description": "Type of product"
                                    },
                                    "target_audience": {
                                        "type": "string",
                                        "description": "Target audience"
                                    },
                                    "key_features": {
                                        "type": "array",
                                        "description": "Key features to highlight",
                                        "items": {"type": "string"}
                                    },
                                    "brand_guidelines": {
                                        "type": "string",
                                        "description": "Brand guidelines reference"
                                    },
                                    "tone": {
                                        "type": "string",
                                        "description": "Desired tone"
                                    }
                                }
                            },
                            "references": {
                                "type": "array",
                                "description": "Reference materials",
                                "items": {
                                    "type": "object",
                                    "required": ["type", "content"],
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "description": "Type of reference"
                                        },
                                        "content": {
                                            "type": "string",
                                            "description": "Reference content"
                                        },
                                        "relevance_score": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 1,
                                            "description": "Relevance score"
                                        }
                                    }
                                }
                            },
                            "constraints": {
                                "type": "object",
                                "description": "Generation constraints",
                                "properties": {
                                    "max_length": {
                                        "type": "integer",
                                        "description": "Maximum length"
                                    },
                                    "min_length": {
                                        "type": "integer",
                                        "description": "Minimum length"
                                    },
                                    "required_keywords": {
                                        "type": "array",
                                        "description": "Required keywords",
                                        "items": {"type": "string"}
                                    },
                                    "forbidden_terms": {
                                        "type": "array",
                                        "description": "Forbidden terms",
                                        "items": {"type": "string"}
                                    }
                                }
                            }
                        }
                    },
                    "generation_requirements": {
                        "type": "object",
                        "description": "Generation requirements",
                        "required": ["language"],
                        "properties": {
                            "language": {
                                "type": "string",
                                "description": "Target language"
                            },
                            "style": {
                                "type": "object",
                                "description": "Style requirements",
                                "properties": {
                                    "tone": {
                                        "type": "string",
                                        "description": "Tone of voice"
                                    },
                                    "formality": {
                                        "type": "string",
                                        "enum": ["informal", "neutral", "formal"],
                                        "description": "Formality level"
                                    },
                                    "creativity_level": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Creativity level"
                                    },
                                    "persuasion_level": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Persuasion level"
                                    }
                                }
                            },
                            "structure": {
                                "type": "object",
                                "description": "Structure requirements",
                                "properties": {
                                    "format": {
                                        "type": "string",
                                        "description": "Content format"
                                    },
                                    "sections": {
                                        "type": "array",
                                        "description": "Required sections",
                                        "items": {"type": "string"}
                                    },
                                    "paragraph_breaks": {
                                        "type": "boolean",
                                        "description": "Use paragraph breaks"
                                    },
                                    "bullet_points": {
                                        "type": "boolean",
                                        "description": "Use bullet points"
                                    }
                                }
                            },
                            "seo_requirements": {
                                "type": "object",
                                "description": "SEO requirements",
                                "properties": {
                                    "target_keywords": {
                                        "type": "array",
                                        "description": "Target keywords",
                                        "items": {"type": "string"}
                                    },
                                    "keyword_density": {
                                        "type": "number",
                                        "description": "Target keyword density"
                                    },
                                    "meta_description_length": {
                                        "type": "integer",
                                        "description": "Meta description length"
                                    }
                                }
                            }
                        }
                    },
                    "quality_requirements": {
                        "type": "object",
                        "description": "Quality requirements",
                        "properties": {
                            "grammar_check": {
                                "type": "boolean",
                                "description": "Perform grammar check"
                            },
                            "spelling_check": {
                                "type": "boolean",
                                "description": "Perform spelling check"
                            },
                            "readability": {
                                "type": "object",
                                "description": "Readability requirements",
                                "properties": {
                                    "target_score": {
                                        "type": "number",
                                        "description": "Target readability score"
                                    },
                                    "scoring_method": {
                                        "type": "string",
                                        "description": "Readability scoring method"
                                    },
                                    "target_grade_level": {
                                        "type": "string",
                                        "description": "Target grade level"
                                    }
                                }
                            },
                            "uniqueness": {
                                "type": "object",
                                "description": "Uniqueness requirements",
                                "properties": {
                                    "min_uniqueness": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Minimum uniqueness score"
                                    },
                                    "check_method": {
                                        "type": "string",
                                        "description": "Uniqueness check method"
                                    }
                                }
                            },
                            "brand_compliance": {
                                "type": "object",
                                "description": "Brand compliance requirements",
                                "properties": {
                                    "voice_guidelines": {
                                        "type": "string",
                                        "description": "Voice guidelines reference"
                                    },
                                    "terminology": {
                                        "type": "string",
                                        "description": "Terminology reference"
                                    },
                                    "compliance_level": {
                                        "type": "string",
                                        "enum": ["loose", "moderate", "strict"],
                                        "description": "Compliance level"
                                    }
                                }
                            }
                        }
                    },
                    "output_specifications": {
                        "type": "object",
                        "description": "Output specifications",
                        "properties": {
                            "format": {
                                "type": "string",
                                "enum": ["plain_text", "html", "markdown", "json"],
                                "description": "Output format"
                            },
                            "sections": {
                                "type": "object",
                                "description": "Required output sections",
                                "properties": {
                                    "main_content": {
                                        "type": "boolean",
                                        "description": "Include main content"
                                    },
                                    "meta_description": {
                                        "type": "boolean",
                                        "description": "Include meta description"
                                    },
                                    "keywords": {
                                        "type": "boolean",
                                        "description": "Include keywords"
                                    },
                                    "headers": {
                                        "type": "boolean",
                                        "description": "Include headers"
                                    }
                                }
                            },
                            "variants": {
                                "type": "object",
                                "description": "Output variants",
                                "properties": {
                                    "count": {
                                        "type": "integer",
                                        "minimum": 1,
                                        "description": "Number of variants"
                                    },
                                    "variation_level": {
                                        "type": "string",
                                        "enum": ["minimal", "moderate", "significant"],
                                        "description": "Level of variation"
                                    }
                                }
                            },
                            "metadata": {
                                "type": "object",
                                "description": "Output metadata",
                                "properties": {
                                    "include_stats": {
                                        "type": "boolean",
                                        "description": "Include statistics"
                                    },
                                    "include_scores": {
                                        "type": "boolean",
                                        "description": "Include quality scores"
                                    },
                                    "include_keywords": {
                                        "type": "boolean",
                                        "description": "Include keyword analysis"
                                    }
                                }
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
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the task"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Task version"
                            },
                            "priority": {
                                "type": "string",
                                "enum": ["low", "normal", "high", "urgent"],
                                "description": "Task priority"
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