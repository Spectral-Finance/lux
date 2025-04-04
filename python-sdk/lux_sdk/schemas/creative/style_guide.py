"""
Schema for design and style guidelines.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class StyleGuideSchema(SignalSchema):
    """Schema for representing design and style guidelines.
    
    This schema defines the structure for representing design and style guidelines,
    including brand identity, visual elements, components, and content guidelines.
    It helps maintain consistency in design and communication across products and platforms.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "guide_id": "style_20240403_153000",
            "brand_id": "brand_789",
            "brand_identity": {
                "name": "TechCorp",
                "mission": "Empowering innovation through technology",
                "values": ["Innovation", "Reliability", "User-Centric"],
                "voice": "Professional yet approachable",
                "personality": ["Innovative", "Trustworthy", "Helpful"]
            },
            "visual_elements": {
                "colors": [{
                    "name": "Primary Blue",
                    "hex_value": "#0066CC",
                    "rgb_value": "0,102,204",
                    "usage": "Primary brand color, used for main CTAs",
                    "accessibility": {
                        "wcag_level": "AAA",
                        "contrast_ratio": 7.5
                    }
                }],
                "typography": {
                    "primary_font": "Roboto",
                    "secondary_font": "Open Sans",
                    "font_sizes": [{
                        "name": "h1",
                        "size": "2.5rem",
                        "line_height": "3rem",
                        "weight": "700"
                    }]
                },
                "spacing": {
                    "scale": ["4px", "8px", "16px", "24px", "32px"],
                    "usage": {
                        "small": "4px for tight spacing",
                        "medium": "16px for standard spacing",
                        "large": "32px for section spacing"
                    }
                },
                "grid_system": {
                    "columns": 12,
                    "gutter": "16px",
                    "margin": "24px",
                    "breakpoints": [{
                        "name": "mobile",
                        "value": "320px"
                    }]
                }
            },
            "components": [{
                "name": "Button",
                "description": "Standard button component",
                "variants": [{
                    "name": "primary",
                    "specs": {
                        "background": "#0066CC",
                        "padding": "12px 24px"
                    },
                    "usage": "Main call-to-action buttons",
                    "examples": ["Submit form", "Start trial"]
                }],
                "accessibility": {
                    "aria_roles": ["button"],
                    "keyboard_support": "Enter and Space to activate"
                }
            }],
            "patterns": [{
                "name": "Form Layout",
                "description": "Standard form layout pattern",
                "use_cases": ["User registration", "Settings forms"],
                "implementation": "Stack form fields vertically with consistent spacing",
                "examples": ["Registration form", "Profile settings"]
            }],
            "content_guidelines": {
                "tone_of_voice": {
                    "characteristics": ["Clear", "Professional", "Friendly"],
                    "examples": {
                        "do": ["Welcome to our platform", "Here's how to get started"],
                        "dont": ["Hey there!", "You messed up"]
                    }
                },
                "writing_style": {
                    "grammar_rules": ["Use active voice", "Keep sentences concise"],
                    "formatting": {
                        "headings": "Title Case",
                        "body": "Sentence case"
                    },
                    "terminology": {
                        "approved": ["sign in", "create account"],
                        "deprecated": ["login", "register"]
                    }
                }
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "designer_123",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "active",
                "contributors": ["designer_123", "writer_456"],
                "review_cycle": "quarterly",
                "tags": ["brand", "design system", "guidelines"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="style_guide",
            version="1.0",
            description="Schema for representing design and style guidelines",
            schema={
                "type": "object",
                "required": ["timestamp", "guide_id", "brand_id", "brand_identity", "visual_elements"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the style guide was created"
                    },
                    "guide_id": {
                        "type": "string",
                        "description": "Unique identifier for the style guide"
                    },
                    "brand_id": {
                        "type": "string",
                        "description": "Identifier of the associated brand"
                    },
                    "brand_identity": {
                        "type": "object",
                        "required": ["name", "mission", "values"],
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Brand name"
                            },
                            "mission": {
                                "type": "string",
                                "description": "Brand mission statement"
                            },
                            "values": {
                                "type": "array",
                                "description": "Core brand values",
                                "items": {"type": "string"}
                            },
                            "voice": {
                                "type": "string",
                                "description": "Brand voice description"
                            },
                            "personality": {
                                "type": "array",
                                "description": "Brand personality traits",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "visual_elements": {
                        "type": "object",
                        "required": ["colors", "typography"],
                        "properties": {
                            "colors": {
                                "type": "array",
                                "description": "Color palette specifications",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "hex_value"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Color name"
                                        },
                                        "hex_value": {
                                            "type": "string",
                                            "pattern": "^#[0-9A-Fa-f]{6}$",
                                            "description": "Hex color code"
                                        },
                                        "rgb_value": {
                                            "type": "string",
                                            "pattern": "^\\d{1,3},\\d{1,3},\\d{1,3}$",
                                            "description": "RGB color values"
                                        },
                                        "usage": {
                                            "type": "string",
                                            "description": "Usage guidelines"
                                        },
                                        "accessibility": {
                                            "type": "object",
                                            "description": "Accessibility considerations",
                                            "properties": {
                                                "wcag_level": {
                                                    "type": "string",
                                                    "enum": ["A", "AA", "AAA"],
                                                    "description": "WCAG compliance level"
                                                },
                                                "contrast_ratio": {
                                                    "type": "number",
                                                    "minimum": 1,
                                                    "maximum": 21,
                                                    "description": "Minimum contrast ratio"
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "typography": {
                                "type": "object",
                                "required": ["primary_font"],
                                "description": "Typography specifications",
                                "properties": {
                                    "primary_font": {
                                        "type": "string",
                                        "description": "Primary font family"
                                    },
                                    "secondary_font": {
                                        "type": "string",
                                        "description": "Secondary font family"
                                    },
                                    "font_sizes": {
                                        "type": "array",
                                        "description": "Font size scale",
                                        "items": {
                                            "type": "object",
                                            "required": ["name", "size"],
                                            "properties": {
                                                "name": {
                                                    "type": "string",
                                                    "description": "Size name (e.g., h1, body)"
                                                },
                                                "size": {
                                                    "type": "string",
                                                    "description": "Font size value"
                                                },
                                                "line_height": {
                                                    "type": "string",
                                                    "description": "Line height value"
                                                },
                                                "weight": {
                                                    "type": "string",
                                                    "description": "Font weight"
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "spacing": {
                                "type": "object",
                                "description": "Spacing system",
                                "properties": {
                                    "scale": {
                                        "type": "array",
                                        "description": "Spacing scale values",
                                        "items": {"type": "string"}
                                    },
                                    "usage": {
                                        "type": "object",
                                        "description": "Usage guidelines for spacing"
                                    }
                                }
                            },
                            "grid_system": {
                                "type": "object",
                                "description": "Layout grid specifications",
                                "properties": {
                                    "columns": {
                                        "type": "integer",
                                        "minimum": 1,
                                        "description": "Number of columns"
                                    },
                                    "gutter": {
                                        "type": "string",
                                        "description": "Gutter width"
                                    },
                                    "margin": {
                                        "type": "string",
                                        "description": "Margin width"
                                    },
                                    "breakpoints": {
                                        "type": "array",
                                        "description": "Responsive breakpoints",
                                        "items": {
                                            "type": "object",
                                            "required": ["name", "value"],
                                            "properties": {
                                                "name": {
                                                    "type": "string",
                                                    "description": "Breakpoint name"
                                                },
                                                "value": {
                                                    "type": "string",
                                                    "description": "Breakpoint value"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "components": {
                        "type": "array",
                        "description": "Component design specifications",
                        "items": {
                            "type": "object",
                            "required": ["name", "description"],
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Component name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Component description"
                                },
                                "variants": {
                                    "type": "array",
                                    "description": "Component variants",
                                    "items": {
                                        "type": "object",
                                        "required": ["name"],
                                        "properties": {
                                            "name": {
                                                "type": "string",
                                                "description": "Variant name"
                                            },
                                            "specs": {
                                                "type": "object",
                                                "description": "Design specifications"
                                            },
                                            "usage": {
                                                "type": "string",
                                                "description": "Usage guidelines"
                                            },
                                            "examples": {
                                                "type": "array",
                                                "description": "Example implementations",
                                                "items": {"type": "string"}
                                            }
                                        }
                                    }
                                },
                                "accessibility": {
                                    "type": "object",
                                    "description": "Accessibility requirements",
                                    "properties": {
                                        "aria_roles": {
                                            "type": "array",
                                            "description": "Required ARIA roles",
                                            "items": {"type": "string"}
                                        },
                                        "keyboard_support": {
                                            "type": "string",
                                            "description": "Keyboard interaction support"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "patterns": {
                        "type": "array",
                        "description": "Design patterns and usage guidelines",
                        "items": {
                            "type": "object",
                            "required": ["name", "description"],
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Pattern name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Pattern description"
                                },
                                "use_cases": {
                                    "type": "array",
                                    "description": "Use cases",
                                    "items": {"type": "string"}
                                },
                                "implementation": {
                                    "type": "string",
                                    "description": "Implementation guidelines"
                                },
                                "examples": {
                                    "type": "array",
                                    "description": "Example applications",
                                    "items": {"type": "string"}
                                }
                            }
                        }
                    },
                    "content_guidelines": {
                        "type": "object",
                        "description": "Content creation guidelines",
                        "properties": {
                            "tone_of_voice": {
                                "type": "object",
                                "description": "Voice and tone guidelines",
                                "properties": {
                                    "characteristics": {
                                        "type": "array",
                                        "description": "Voice characteristics",
                                        "items": {"type": "string"}
                                    },
                                    "examples": {
                                        "type": "object",
                                        "description": "Example applications",
                                        "properties": {
                                            "do": {
                                                "type": "array",
                                                "description": "Good examples",
                                                "items": {"type": "string"}
                                            },
                                            "dont": {
                                                "type": "array",
                                                "description": "Bad examples",
                                                "items": {"type": "string"}
                                            }
                                        }
                                    }
                                }
                            },
                            "writing_style": {
                                "type": "object",
                                "description": "Writing style guidelines",
                                "properties": {
                                    "grammar_rules": {
                                        "type": "array",
                                        "description": "Grammar rules",
                                        "items": {"type": "string"}
                                    },
                                    "formatting": {
                                        "type": "object",
                                        "description": "Text formatting guidelines"
                                    },
                                    "terminology": {
                                        "type": "object",
                                        "description": "Preferred terminology",
                                        "properties": {
                                            "approved": {
                                                "type": "array",
                                                "description": "Approved terms",
                                                "items": {"type": "string"}
                                            },
                                            "deprecated": {
                                                "type": "array",
                                                "description": "Deprecated terms",
                                                "items": {"type": "string"}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the style guide",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Style guide creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Style guide version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "deprecated"],
                                "description": "Status"
                            },
                            "contributors": {
                                "type": "array",
                                "description": "Contributing team members",
                                "items": {"type": "string"}
                            },
                            "review_cycle": {
                                "type": "string",
                                "description": "Review frequency"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {"type": "string"}
                            }
                        }
                    }
                }
            }
        ) 