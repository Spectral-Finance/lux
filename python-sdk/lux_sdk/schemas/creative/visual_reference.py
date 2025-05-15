"""
Visual Reference Schema

This schema represents visual references and inspiration sources,
including images, annotations, and usage context.
"""

from lux_sdk.signals import SignalSchema

VisualReferenceSchema = SignalSchema(
    name="visual_reference",
    version="1.0",
    description="Schema for visual references and inspiration sources",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "reference_id": {
                "type": "string",
                "description": "Unique identifier for this reference"
            },
            "title": {
                "type": "string",
                "description": "Reference title"
            },
            "source": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["photograph", "artwork", "sketch", "digital", "other"],
                        "description": "Type of reference"
                    },
                    "url": {
                        "type": "string",
                        "description": "Source URL"
                    },
                    "creator": {
                        "type": "string",
                        "description": "Original creator"
                    },
                    "license": {
                        "type": "string",
                        "description": "Usage license"
                    }
                },
                "required": ["type"]
            },
            "annotations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "region": {
                            "type": "object",
                            "properties": {
                                "x": {"type": "number"},
                                "y": {"type": "number"},
                                "width": {"type": "number"},
                                "height": {"type": "number"}
                            },
                            "required": ["x", "y", "width", "height"]
                        },
                        "note": {
                            "type": "string",
                            "description": "Annotation text"
                        },
                        "category": {
                            "type": "string",
                            "description": "Annotation category"
                        }
                    },
                    "required": ["region", "note"]
                }
            },
            "usage_context": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "project_id": {
                            "type": "string",
                            "description": "Associated project"
                        },
                        "purpose": {
                            "type": "string",
                            "description": "Purpose of reference"
                        },
                        "elements": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Referenced elements"
                            }
                        }
                    },
                    "required": ["project_id", "purpose"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the reference"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the reference"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": ["timestamp", "reference_id", "title", "source"]
    }
) 