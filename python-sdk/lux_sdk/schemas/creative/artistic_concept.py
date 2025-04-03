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
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "concept_id": {"type": "string", "required": True},
            "title": {"type": "string", "required": True},
            "description": {"type": "string", "required": True},
            "medium": {
                "type": "object",
                "required": True,
                "properties": {
                    "primary": {"type": "string", "required": True},
                    "secondary": {"type": "array", "items": {"type": "string"}},
                    "techniques": {"type": "array", "items": {"type": "string"}, "required": True}
                }
            },
            "visual_elements": {
                "type": "object",
                "required": True,
                "properties": {
                    "color_palette": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "color": {"type": "string", "required": True},
                                "role": {"type": "string", "required": True},
                                "hex_value": {"type": "string", "pattern": "^#[0-9A-Fa-f]{6}$", "required": True}
                            }
                        }
                    },
                    "composition": {
                        "type": "object",
                        "properties": {
                            "layout": {"type": "string", "required": True},
                            "focal_points": {"type": "array", "items": {"type": "string"}},
                            "balance": {"type": "string", "enum": ["symmetrical", "asymmetrical", "radial"]},
                            "perspective": {"type": "string"}
                        }
                    },
                    "texture": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string", "required": True},
                                "application": {"type": "string", "required": True}
                            }
                        }
                    }
                }
            },
            "style": {
                "type": "object",
                "required": True,
                "properties": {
                    "movement": {"type": "string"},
                    "influences": {"type": "array", "items": {"type": "string"}},
                    "period": {"type": "string"},
                    "characteristics": {"type": "array", "items": {"type": "string"}, "required": True}
                }
            },
            "thematic_elements": {
                "type": "object",
                "required": True,
                "properties": {
                    "main_theme": {"type": "string", "required": True},
                    "sub_themes": {"type": "array", "items": {"type": "string"}},
                    "symbolism": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "element": {"type": "string", "required": True},
                                "meaning": {"type": "string", "required": True}
                            }
                        }
                    },
                    "emotional_tone": {"type": "string", "required": True}
                }
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
                                "name": {"type": "string", "required": True},
                                "quantity": {"type": "string"},
                                "specifications": {"type": "string"}
                            }
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
                        "type": {"type": "string", "required": True},
                        "source": {"type": "string", "required": True},
                        "description": {"type": "string"},
                        "url": {"type": "string"}
                    }
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
        }
    }
) 