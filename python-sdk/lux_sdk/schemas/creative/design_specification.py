"""
Schema for creative design specifications and requirements.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class DesignSpecificationSchema(SignalSchema):
    """Schema for representing creative design specifications and requirements.
    
    This schema defines the structure for design specifications, including visual elements,
    layout, components, interactions, and accessibility requirements.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "specification_id": "spec_123",
            "project_id": "proj_456",
            "overview": {
                "title": "Mobile App Redesign",
                "description": "Modern, user-friendly interface redesign",
                "purpose": "Improve user engagement and accessibility",
                "target_audience": ["young professionals", "tech-savvy users"],
                "context": "Mobile application"
            },
            "visual_elements": {
                "color_palette": [{
                    "name": "Primary Blue",
                    "hex_code": "#0066CC",
                    "usage": "Primary action buttons and links"
                }],
                "typography": {
                    "primary_font": "Roboto",
                    "secondary_font": "Open Sans",
                    "font_sizes": {
                        "heading": "24px",
                        "body": "16px"
                    },
                    "line_heights": {
                        "heading": "1.2",
                        "body": "1.5"
                    }
                },
                "imagery": {
                    "style": "Modern and minimalist",
                    "formats": ["SVG", "PNG", "WebP"],
                    "resolution": "2x for retina displays"
                }
            },
            "layout": {
                "grid_system": {
                    "columns": 12,
                    "gutters": "16px",
                    "margins": "24px"
                },
                "spacing": {
                    "vertical": "Multiple of 8px",
                    "horizontal": "Multiple of 8px"
                },
                "responsive_behavior": {
                    "breakpoints": ["320px", "768px", "1024px", "1440px"],
                    "adaptations": ["Stack on mobile", "Side-by-side on tablet"]
                }
            },
            "components": [{
                "component_id": "btn_primary",
                "name": "Primary Button",
                "description": "Main call-to-action button",
                "specifications": {
                    "padding": "12px 24px",
                    "border_radius": "4px"
                },
                "variations": ["default", "hover", "active", "disabled"],
                "usage_guidelines": "Use for primary actions only"
            }],
            "interactions": [{
                "interaction_id": "btn_click",
                "type": "click",
                "description": "Button click interaction",
                "triggers": ["mouse click", "touch"],
                "feedback": "Visual feedback on press",
                "animations": {
                    "duration": "200ms",
                    "easing": "ease-in-out"
                }
            }],
            "accessibility": {
                "standards": ["WCAG 2.1", "Section 508"],
                "color_contrast": {
                    "minimum_ratio": "4.5:1"
                },
                "keyboard_navigation": {
                    "tab_order": "logical flow",
                    "focus_indicators": "visible"
                },
                "screen_reader": {
                    "aria_labels": "descriptive",
                    "landmarks": "semantic HTML"
                }
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "updated_at": "2024-04-03T15:30:00Z",
                "created_by": "designer_123",
                "version": "1.0",
                "status": "in_review",
                "tags": ["mobile", "redesign", "modern"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="design_specification",
            version="1.0",
            description="Schema for representing creative design specifications and requirements",
            schema={
                "type": "object",
                "required": ["timestamp", "specification_id", "project_id", "overview", "visual_elements", "layout"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the design specification"
                    },
                    "specification_id": {
                        "type": "string",
                        "description": "Unique identifier for the design specification"
                    },
                    "project_id": {
                        "type": "string",
                        "description": "Reference to the associated project"
                    },
                    "overview": {
                        "type": "object",
                        "required": ["title", "description", "purpose"],
                        "properties": {
                            "title": {
                                "type": "string",
                                "description": "Title of the design"
                            },
                            "description": {
                                "type": "string",
                                "description": "Description of the design"
                            },
                            "purpose": {
                                "type": "string",
                                "description": "Purpose or goal of the design"
                            },
                            "target_audience": {
                                "type": "array",
                                "description": "Intended audience",
                                "items": {"type": "string"}
                            },
                            "context": {
                                "type": "string",
                                "description": "Context or environment of use"
                            }
                        }
                    },
                    "visual_elements": {
                        "type": "object",
                        "required": ["color_palette", "typography"],
                        "properties": {
                            "color_palette": {
                                "type": "array",
                                "description": "Color specifications",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "hex_code"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Name of the color"
                                        },
                                        "hex_code": {
                                            "type": "string",
                                            "pattern": "^#[0-9A-Fa-f]{6}$",
                                            "description": "Hex color code"
                                        },
                                        "usage": {
                                            "type": "string",
                                            "description": "Intended usage"
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
                                        "type": "object",
                                        "description": "Font size specifications"
                                    },
                                    "line_heights": {
                                        "type": "object",
                                        "description": "Line height specifications"
                                    }
                                }
                            },
                            "imagery": {
                                "type": "object",
                                "description": "Image specifications",
                                "properties": {
                                    "style": {
                                        "type": "string",
                                        "description": "Image style guidelines"
                                    },
                                    "formats": {
                                        "type": "array",
                                        "description": "Acceptable formats",
                                        "items": {"type": "string"}
                                    },
                                    "resolution": {
                                        "type": "string",
                                        "description": "Required resolution"
                                    }
                                }
                            }
                        }
                    },
                    "layout": {
                        "type": "object",
                        "required": ["grid_system"],
                        "properties": {
                            "grid_system": {
                                "type": "object",
                                "required": ["columns"],
                                "description": "Grid specifications",
                                "properties": {
                                    "columns": {
                                        "type": "integer",
                                        "minimum": 1,
                                        "description": "Number of columns"
                                    },
                                    "gutters": {
                                        "type": "string",
                                        "description": "Gutter specifications"
                                    },
                                    "margins": {
                                        "type": "string",
                                        "description": "Margin specifications"
                                    }
                                }
                            },
                            "spacing": {
                                "type": "object",
                                "description": "Spacing guidelines",
                                "properties": {
                                    "vertical": {
                                        "type": "string",
                                        "description": "Vertical spacing rules"
                                    },
                                    "horizontal": {
                                        "type": "string",
                                        "description": "Horizontal spacing rules"
                                    }
                                }
                            },
                            "responsive_behavior": {
                                "type": "object",
                                "description": "Responsive design specifications",
                                "properties": {
                                    "breakpoints": {
                                        "type": "array",
                                        "description": "Breakpoint definitions",
                                        "items": {"type": "string"}
                                    },
                                    "adaptations": {
                                        "type": "array",
                                        "description": "Layout adaptations",
                                        "items": {"type": "string"}
                                    }
                                }
                            }
                        }
                    },
                    "components": {
                        "type": "array",
                        "description": "Design components",
                        "items": {
                            "type": "object",
                            "required": ["component_id", "name", "description"],
                            "properties": {
                                "component_id": {
                                    "type": "string",
                                    "description": "Component identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Component name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Component description"
                                },
                                "specifications": {
                                    "type": "object",
                                    "description": "Component specifications"
                                },
                                "variations": {
                                    "type": "array",
                                    "description": "Component variations",
                                    "items": {"type": "string"}
                                },
                                "usage_guidelines": {
                                    "type": "string",
                                    "description": "Usage guidelines"
                                }
                            }
                        }
                    },
                    "interactions": {
                        "type": "array",
                        "description": "Interaction specifications",
                        "items": {
                            "type": "object",
                            "required": ["interaction_id", "type", "description"],
                            "properties": {
                                "interaction_id": {
                                    "type": "string",
                                    "description": "Interaction identifier"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["click", "hover", "scroll", "swipe", "drag", "pinch", "keyboard"],
                                    "description": "Type of interaction"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of interaction"
                                },
                                "triggers": {
                                    "type": "array",
                                    "description": "Interaction triggers",
                                    "items": {"type": "string"}
                                },
                                "feedback": {
                                    "type": "string",
                                    "description": "User feedback specifications"
                                },
                                "animations": {
                                    "type": "object",
                                    "description": "Animation specifications"
                                }
                            }
                        }
                    },
                    "accessibility": {
                        "type": "object",
                        "description": "Accessibility requirements",
                        "properties": {
                            "standards": {
                                "type": "array",
                                "description": "Accessibility standards to meet",
                                "items": {"type": "string"}
                            },
                            "color_contrast": {
                                "type": "object",
                                "description": "Color contrast requirements"
                            },
                            "keyboard_navigation": {
                                "type": "object",
                                "description": "Keyboard navigation specifications"
                            },
                            "screen_reader": {
                                "type": "object",
                                "description": "Screen reader support specifications"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the design specification",
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
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the specification"
                            },
                            "version": {
                                "type": "string",
                                "description": "Version of the specification"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "in_review", "approved", "deprecated"],
                                "description": "Current status"
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