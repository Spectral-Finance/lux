"""
Composition Layout Schema

This schema represents composition and layout specifications,
including canvas properties, elements, and spatial relationships.
"""

from lux_sdk.signals import SignalSchema

CompositionLayoutSchema = SignalSchema(
    name="composition_layout",
    version="1.0",
    description="Schema for composition and layout specifications",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "layout_id": {
                "type": "string",
                "description": "Unique identifier for this layout"
            },
            "name": {
                "type": "string",
                "description": "Name of the composition"
            },
            "canvas": {
                "type": "object",
                "properties": {
                    "width": {
                        "type": "number",
                        "description": "Width of the canvas"
                    },
                    "height": {
                        "type": "number",
                        "description": "Height of the canvas"
                    },
                    "units": {
                        "type": "string",
                        "enum": ["pixels", "points", "inches", "centimeters", "percent"],
                        "description": "Units of measurement"
                    }
                },
                "required": ["width", "height", "units"]
            },
            "elements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "element_id": {
                            "type": "string",
                            "description": "Unique identifier for the element"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["shape", "text", "image", "group"],
                            "description": "Type of element"
                        },
                        "position": {
                            "type": "object",
                            "properties": {
                                "x": {"type": "number"},
                                "y": {"type": "number"},
                                "z_index": {"type": "integer"}
                            },
                            "required": ["x", "y"]
                        },
                        "dimensions": {
                            "type": "object",
                            "properties": {
                                "width": {"type": "number"},
                                "height": {"type": "number"},
                                "rotation": {"type": "number"}
                            },
                            "required": ["width", "height"]
                        }
                    },
                    "required": ["element_id", "type", "position"]
                }
            },
            "grid": {
                "type": "object",
                "properties": {
                    "enabled": {
                        "type": "boolean",
                        "description": "Whether grid is enabled"
                    },
                    "size": {
                        "type": "number",
                        "description": "Grid cell size"
                    },
                    "snap_to_grid": {
                        "type": "boolean",
                        "description": "Whether elements should snap to grid"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the layout"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the layout"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": ["timestamp", "layout_id", "name", "canvas", "elements"]
    }
) 