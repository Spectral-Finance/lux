"""
Narrative Structure Schema

This schema represents narrative structure and storytelling elements,
including plot points, character arcs, and story progression.
"""

from lux_sdk.signals import SignalSchema

NarrativeStructureSchema = SignalSchema(
    name="narrative_structure",
    version="1.0",
    description="Schema for narrative structure and storytelling elements",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "narrative_id": {
                "type": "string",
                "description": "Unique identifier for this narrative"
            },
            "title": {
                "type": "string",
                "description": "Title of the narrative"
            },
            "structure_type": {
                "type": "string",
                "enum": ["linear", "nonlinear", "parallel", "episodic", "circular"],
                "description": "Type of narrative structure"
            },
            "plot_points": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "point_id": {
                            "type": "string",
                            "description": "Unique identifier for the plot point"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["setup", "inciting_incident", "rising_action", "climax", "falling_action", "resolution"],
                            "description": "Type of plot point"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the plot point"
                        },
                        "sequence": {
                            "type": "integer",
                            "description": "Order in the narrative"
                        }
                    },
                    "required": ["point_id", "type", "description"]
                }
            },
            "character_arcs": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "character_id": {
                            "type": "string",
                            "description": "Reference to character"
                        },
                        "arc_type": {
                            "type": "string",
                            "enum": ["growth", "fall", "transformation", "static"],
                            "description": "Type of character arc"
                        },
                        "key_moments": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "plot_point_id": {
                                        "type": "string",
                                        "description": "Reference to plot point"
                                    },
                                    "impact": {
                                        "type": "string",
                                        "description": "Impact on character"
                                    }
                                },
                                "required": ["plot_point_id"]
                            }
                        }
                    },
                    "required": ["character_id", "arc_type"]
                }
            },
            "themes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "Theme name"
                        },
                        "development": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "plot_point_id": {
                                        "type": "string",
                                        "description": "Reference to plot point"
                                    },
                                    "expression": {
                                        "type": "string",
                                        "description": "How theme is expressed"
                                    }
                                },
                                "required": ["plot_point_id", "expression"]
                            }
                        }
                    },
                    "required": ["name"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "author": {
                        "type": "string",
                        "description": "Author of the narrative"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "genre": {
                        "type": "string",
                        "description": "Genre of the narrative"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": ["timestamp", "narrative_id", "title", "structure_type", "plot_points"]
    }
) 