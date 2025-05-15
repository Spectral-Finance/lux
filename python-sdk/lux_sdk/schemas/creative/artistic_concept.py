"""
ArtisticConceptSchema

This schema represents artistic concept specifications, including
visual elements, composition, style, and thematic elements.
"""

from lux_sdk.signals import SignalSchema

ArtisticConceptSchema = SignalSchema(
    name="artistic_concept",
    version="1.0",
    description="Schema for representing artistic concept specifications and elements",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time"},
            "concept_id": {"type": "string"},
            "title": {"type": "string"},
            "description": {"type": "string"},
            "medium": {
                "type": "object",
                "properties": {
                    "primary": {"type": "string"},
                    "secondary": {"type": "array", "items": {"type": "string"}},
                    "techniques": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["primary", "techniques"]
            },
            "visual_elements": {
                "type": "object",
                "properties": {
                    "color_palette": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "color": {"type": "string"},
                                "role": {"type": "string"},
                                "hex_value": {"type": "string", "pattern": "^#[0-9A-Fa-f]{6}$"}
                            },
                            "required": ["color", "role", "hex_value"]
                        }
                    },
                    "composition": {
                        "type": "object",
                        "properties": {
                            "layout": {"type": "string"},
                            "focal_points": {"type": "array", "items": {"type": "string"}},
                            "balance": {"type": "string", "enum": ["symmetrical", "asymmetrical", "radial"]},
                            "perspective": {"type": "string"}
                        },
                        "required": ["layout"]
                    },
                    "texture": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"},
                                "application": {"type": "string"}
                            },
                            "required": ["type", "application"]
                        }
                    }
                }
            },
            "style": {
                "type": "object",
                "properties": {
                    "movement": {"type": "string"},
                    "influences": {"type": "array", "items": {"type": "string"}},
                    "period": {"type": "string"},
                    "characteristics": {"type": "array", "items": {"type": "string"}}
                },
                "required": ["characteristics"]
            },
            "thematic_elements": {
                "type": "object",
                "properties": {
                    "main_theme": {"type": "string"},
                    "sub_themes": {"type": "array", "items": {"type": "string"}},
                    "symbolism": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "element": {"type": "string"},
                                "meaning": {"type": "string"}
                            },
                            "required": ["element", "meaning"]
                        }
                    },
                    "emotional_tone": {"type": "string"}
                },
                "required": ["main_theme", "emotional_tone"]
            },
            "technical_requirements": {
                "type": "object",
                "properties": {
                    "dimensions": {
                        "type": "object",
                        "properties": {
                            "width": {"type": "number"},
                            "height": {"type": "number"},
                            "depth": {"type": "number"},
                            "units": {"type": "string"}
                        }
                    },
                    "materials": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "quantity": {"type": "string"},
                                "specifications": {"type": "string"}
                            },
                            "required": ["name"]
                        }
                    },
                    "tools": {"type": "array", "items": {"type": "string"}},
                    "environment": {
                        "type": "object",
                        "properties": {
                            "lighting": {"type": "string"},
                            "temperature": {"type": "string"},
                            "humidity": {"type": "string"}
                        }
                    }
                }
            },
            "references": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string"},
                        "source": {"type": "string"},
                        "description": {"type": "string"},
                        "url": {"type": "string"}
                    },
                    "required": ["type", "source"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {"type": "string"},
                    "creation_date": {"type": "string", "format": "date-time"},
                    "last_modified": {"type": "string", "format": "date-time"},
                    "status": {"type": "string", "enum": ["concept", "in_progress", "completed", "archived"]},
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "copyright": {"type": "string"},
                    "license": {"type": "string"}
                }
            }
        },
        "required": ["timestamp", "concept_id", "title", "description", "medium", "visual_elements", "style", "thematic_elements"]
    }
) 