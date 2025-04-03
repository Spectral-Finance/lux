"""
Composition Layout Schema

This schema represents composition layouts and visual arrangements in creative works,
including spatial relationships, visual hierarchy, and design principles.
"""

from lux_sdk.signals import SignalSchema

CompositionLayoutSchema = SignalSchema(
    name="composition_layout",
    version="1.0",
    description="Schema for composition layouts and visual arrangements",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "layout_id": {
                "type": "string",
                "description": "Unique identifier for this composition layout"
            },
            "name": {
                "type": "string",
                "description": "Name of the composition layout"
            },
            "description": {
                "type": "string",
                "description": "Description of the layout's purpose and style"
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
                    },
                    "background": {
                        "type": "object",
                        "properties": {
                            "color": {
                                "type": "string",
                                "description": "Background color"
                            },
                            "opacity": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Background opacity"
                            }
                        }
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
                            "enum": [
                                "text",
                                "image",
                                "shape",
                                "group",
                                "vector",
                                "container",
                                "other"
                            ],
                            "description": "Type of element"
                        },
                        "position": {
                            "type": "object",
                            "properties": {
                                "x": {
                                    "type": "number",
                                    "description": "X coordinate"
                                },
                                "y": {
                                    "type": "number",
                                    "description": "Y coordinate"
                                },
                                "z_index": {
                                    "type": "integer",
                                    "description": "Z-index for layering"
                                }
                            },
                            "required": ["x", "y"]
                        },
                        "dimensions": {
                            "type": "object",
                            "properties": {
                                "width": {
                                    "type": "number",
                                    "description": "Width of element"
                                },
                                "height": {
                                    "type": "number",
                                    "description": "Height of element"
                                },
                                "rotation": {
                                    "type": "number",
                                    "description": "Rotation angle in degrees"
                                }
                            },
                            "required": ["width", "height"]
                        },
                        "style": {
                            "type": "object",
                            "properties": {
                                "fill": {
                                    "type": "string",
                                    "description": "Fill color"
                                },
                                "stroke": {
                                    "type": "string",
                                    "description": "Stroke color"
                                },
                                "stroke_width": {
                                    "type": "number",
                                    "description": "Stroke width"
                                },
                                "opacity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Element opacity"
                                }
                            }
                        },
                        "content": {
                            "type": "object",
                            "description": "Element-specific content properties"
                        }
                    },
                    "required": ["element_id", "type", "position"]
                }
            },
            "grid": {
                "type": "object",
                "properties": {
                    "columns": {
                        "type": "integer",
                        "description": "Number of columns"
                    },
                    "rows": {
                        "type": "integer",
                        "description": "Number of rows"
                    },
                    "gutter": {
                        "type": "object",
                        "properties": {
                            "horizontal": {
                                "type": "number",
                                "description": "Horizontal gutter size"
                            },
                            "vertical": {
                                "type": "number",
                                "description": "Vertical gutter size"
                            }
                        }
                    },
                    "margin": {
                        "type": "object",
                        "properties": {
                            "top": {
                                "type": "number",
                                "description": "Top margin"
                            },
                            "right": {
                                "type": "number",
                                "description": "Right margin"
                            },
                            "bottom": {
                                "type": "number",
                                "description": "Bottom margin"
                            },
                            "left": {
                                "type": "number",
                                "description": "Left margin"
                            }
                        }
                    }
                }
            },
            "constraints": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": [
                                "alignment",
                                "spacing",
                                "size",
                                "position",
                                "proportion"
                            ],
                            "description": "Type of constraint"
                        },
                        "elements": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Element IDs involved in constraint"
                            }
                        },
                        "parameters": {
                            "type": "object",
                            "description": "Constraint-specific parameters"
                        }
                    },
                    "required": ["type", "elements"]
                }
            },
            "principles": {
                "type": "object",
                "properties": {
                    "balance": {
                        "type": "string",
                        "enum": ["symmetrical", "asymmetrical", "radial"],
                        "description": "Type of visual balance"
                    },
                    "emphasis": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Element IDs with visual emphasis"
                        }
                    },
                    "rhythm": {
                        "type": "string",
                        "enum": ["regular", "flowing", "progressive"],
                        "description": "Visual rhythm pattern"
                    },
                    "unity": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "elements": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Element IDs in unity group"
                                    }
                                },
                                "method": {
                                    "type": "string",
                                    "enum": ["proximity", "similarity", "continuation", "closure"],
                                    "description": "Method of achieving unity"
                                }
                            }
                        }
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
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the layout"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Relevant tags"
                        }
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "layout_id",
            "name",
            "canvas",
            "elements"
        ]
    }
) 