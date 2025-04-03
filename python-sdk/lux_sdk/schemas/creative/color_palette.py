"""
Color Palette Schema

This schema represents color palettes and their properties,
including color definitions, relationships, and usage guidelines.
"""

from lux_sdk.signals import SignalSchema

ColorPaletteSchema = SignalSchema(
    name="color_palette",
    version="1.0",
    description="Schema for representing color palettes and their properties",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "palette_id": {
                "type": "string",
                "description": "Unique identifier for the color palette"
            },
            "name": {
                "type": "string",
                "description": "Name of the color palette"
            },
            "colors": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "color_id": {
                            "type": "string",
                            "description": "Identifier for the color"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the color"
                        },
                        "hex_value": {
                            "type": "string",
                            "pattern": "^#[0-9A-Fa-f]{6}$",
                            "description": "Hexadecimal color value"
                        },
                        "rgb": {
                            "type": "object",
                            "properties": {
                                "r": {"type": "integer", "minimum": 0, "maximum": 255},
                                "g": {"type": "integer", "minimum": 0, "maximum": 255},
                                "b": {"type": "integer", "minimum": 0, "maximum": 255}
                            },
                            "required": ["r", "g", "b"]
                        },
                        "role": {
                            "type": "string",
                            "enum": ["primary", "secondary", "accent", "background", "text"],
                            "description": "Role of the color in the palette"
                        }
                    },
                    "required": ["color_id", "hex_value", "rgb"]
                }
            },
            "relationships": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": ["complementary", "analogous", "triadic", "tetradic"],
                            "description": "Type of color relationship"
                        },
                        "colors": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Color IDs involved in the relationship"
                        }
                    },
                    "required": ["type", "colors"]
                }
            },
            "usage_guidelines": {
                "type": "object",
                "properties": {
                    "primary_background": {
                        "type": "string",
                        "description": "Color ID for primary background"
                    },
                    "primary_text": {
                        "type": "string",
                        "description": "Color ID for primary text"
                    },
                    "contrast_ratios": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "foreground": {"type": "string"},
                                "background": {"type": "string"},
                                "ratio": {"type": "number", "minimum": 1},
                                "wcag_level": {
                                    "type": "string",
                                    "enum": ["AA", "AAA"]
                                }
                            },
                            "required": ["foreground", "background", "ratio"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the palette"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "inspiration": {
                        "type": "string",
                        "description": "Source of inspiration for the palette"
                    }
                }
            }
        },
        "required": ["timestamp", "palette_id", "name", "colors"]
    }
) 