"""
Schema for representing spatial relationships in environmental contexts.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class SpatialRelationSchema(SignalSchema):
    """Schema for representing spatial relationships and environmental contexts.
    
    This schema defines the structure for representing spatial relationships between
    elements in an environment, including their positions, orientations, distances,
    and environmental factors affecting these relationships.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "relation_id": "spatial_20240403_153000",
            "environment_id": "env_789",
            "spatial_context": {
                "type": "indoor",
                "scale": "room",
                "dimensions": {
                    "width": 10.5,
                    "length": 15.2,
                    "height": 3.0,
                    "unit": "meters"
                },
                "coordinate_system": {
                    "type": "cartesian",
                    "origin": {"x": 0, "y": 0, "z": 0},
                    "orientation": "north_aligned"
                },
                "boundaries": {
                    "type": "polygon",
                    "vertices": [
                        {"x": 0, "y": 0},
                        {"x": 10.5, "y": 0},
                        {"x": 10.5, "y": 15.2},
                        {"x": 0, "y": 15.2}
                    ]
                }
            },
            "spatial_elements": [{
                "element_id": "object_123",
                "type": "furniture",
                "category": "desk",
                "position": {
                    "x": 2.5,
                    "y": 3.0,
                    "z": 0.0,
                    "accuracy": 0.1
                },
                "dimensions": {
                    "width": 1.2,
                    "depth": 0.6,
                    "height": 0.75,
                    "unit": "meters"
                },
                "orientation": {
                    "heading": 90,
                    "unit": "degrees"
                },
                "properties": {
                    "material": "wood",
                    "color": "brown",
                    "weight": "25kg"
                }
            }],
            "relationships": [{
                "type": "proximity",
                "elements": ["object_123", "object_456"],
                "metrics": {
                    "distance": {
                        "value": 1.5,
                        "unit": "meters",
                        "measurement_type": "center_to_center"
                    },
                    "orientation": {
                        "relative_angle": 45,
                        "unit": "degrees"
                    },
                    "clearance": {
                        "value": 0.8,
                        "unit": "meters"
                    }
                },
                "constraints": {
                    "min_distance": 1.0,
                    "max_distance": 2.0,
                    "required_clearance": 0.5
                },
                "temporal_aspects": {
                    "start_time": "2024-04-03T15:00:00Z",
                    "end_time": "2024-04-03T16:00:00Z",
                    "duration": "1h"
                }
            }],
            "environmental_factors": [{
                "type": "lighting",
                "source": {
                    "type": "natural",
                    "direction": "north",
                    "intensity": 500,
                    "unit": "lux"
                },
                "distribution": {
                    "type": "gradient",
                    "pattern": "uniform",
                    "coverage": 0.8
                },
                "affected_elements": ["object_123"],
                "temporal_variation": {
                    "pattern": "diurnal",
                    "peak_time": "12:00",
                    "variation_range": {
                        "min": 100,
                        "max": 1000,
                        "unit": "lux"
                    }
                }
            }],
            "analysis": {
                "space_utilization": {
                    "occupied_area": 45.5,
                    "total_area": 159.6,
                    "utilization_ratio": 0.285,
                    "density_map": {
                        "resolution": "1m",
                        "data": [[0.1, 0.2], [0.3, 0.4]]
                    }
                },
                "accessibility": {
                    "pathways": [{
                        "start": {"x": 0, "y": 0},
                        "end": {"x": 10, "y": 15},
                        "width": 1.2,
                        "clearance_height": 2.1
                    }],
                    "bottlenecks": [{
                        "location": {"x": 5, "y": 7},
                        "width": 0.8,
                        "risk_level": "medium"
                    }]
                },
                "visibility": {
                    "viewpoints": [{
                        "position": {"x": 5, "y": 7},
                        "direction": 180,
                        "field_of_view": 120
                    }],
                    "occlusions": [{
                        "blocker_id": "object_789",
                        "affected_area": {
                            "type": "polygon",
                            "vertices": [[6, 8], [7, 8], [7, 9]]
                        }
                    }]
                }
            },
            "visualization": {
                "style": {
                    "color_scheme": "default",
                    "opacity": 0.8,
                    "line_weight": 2
                },
                "layers": [{
                    "name": "base",
                    "type": "floor_plan",
                    "visible": true,
                    "z_index": 0
                }],
                "annotations": [{
                    "type": "text",
                    "content": "Main Entrance",
                    "position": {"x": 5, "y": 0},
                    "style": {
                        "font_size": 12,
                        "color": "#000000"
                    }
                }],
                "viewport": {
                    "center": {"x": 5.25, "y": 7.6},
                    "zoom": 1.0,
                    "rotation": 0
                }
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "spatial_analyzer",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "active",
                "accuracy_level": "high",
                "data_sources": ["lidar_scan", "manual_measurement"],
                "tags": ["indoor", "office", "space_planning"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="spatial_relation",
            version="1.0",
            description="Schema for representing spatial relationships and environmental contexts",
            schema={
                "type": "object",
                "required": ["timestamp", "relation_id", "environment_id", "spatial_context", "spatial_elements", "relationships"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the spatial relation"
                    },
                    "relation_id": {
                        "type": "string",
                        "description": "Unique identifier for the spatial relation"
                    },
                    "environment_id": {
                        "type": "string",
                        "description": "Identifier of the environmental context"
                    },
                    "spatial_context": {
                        "type": "object",
                        "description": "Environmental spatial context",
                        "required": ["type", "scale"],
                        "properties": {
                            "type": {
                                "type": "string",
                                "enum": ["indoor", "outdoor", "mixed"],
                                "description": "Type of environment"
                            },
                            "scale": {
                                "type": "string",
                                "enum": ["room", "building", "campus", "city", "region"],
                                "description": "Scale of the environment"
                            },
                            "dimensions": {
                                "type": "object",
                                "description": "Physical dimensions",
                                "properties": {
                                    "width": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Width dimension"
                                    },
                                    "length": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Length dimension"
                                    },
                                    "height": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Height dimension"
                                    },
                                    "unit": {
                                        "type": "string",
                                        "description": "Unit of measurement"
                                    }
                                }
                            },
                            "coordinate_system": {
                                "type": "object",
                                "description": "Coordinate system information",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "enum": ["cartesian", "geographic", "relative"],
                                        "description": "Type of coordinate system"
                                    },
                                    "origin": {
                                        "type": "object",
                                        "description": "Origin point",
                                        "properties": {
                                            "x": {"type": "number"},
                                            "y": {"type": "number"},
                                            "z": {"type": "number"}
                                        }
                                    },
                                    "orientation": {
                                        "type": "string",
                                        "description": "Coordinate system orientation"
                                    }
                                }
                            },
                            "boundaries": {
                                "type": "object",
                                "description": "Environment boundaries",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "enum": ["polygon", "rectangle", "circle"],
                                        "description": "Boundary shape type"
                                    },
                                    "vertices": {
                                        "type": "array",
                                        "description": "Boundary vertices",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "x": {"type": "number"},
                                                "y": {"type": "number"}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "spatial_elements": {
                        "type": "array",
                        "description": "Elements in spatial relationship",
                        "items": {
                            "type": "object",
                            "required": ["element_id", "type", "position"],
                            "properties": {
                                "element_id": {
                                    "type": "string",
                                    "description": "Unique identifier for the element"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Type of element"
                                },
                                "category": {
                                    "type": "string",
                                    "description": "Element category"
                                },
                                "position": {
                                    "type": "object",
                                    "description": "Element position",
                                    "properties": {
                                        "x": {"type": "number"},
                                        "y": {"type": "number"},
                                        "z": {"type": "number"},
                                        "accuracy": {
                                            "type": "number",
                                            "minimum": 0,
                                            "description": "Position accuracy"
                                        }
                                    }
                                },
                                "dimensions": {
                                    "type": "object",
                                    "description": "Element dimensions",
                                    "properties": {
                                        "width": {"type": "number", "minimum": 0},
                                        "depth": {"type": "number", "minimum": 0},
                                        "height": {"type": "number", "minimum": 0},
                                        "unit": {"type": "string"}
                                    }
                                },
                                "orientation": {
                                    "type": "object",
                                    "description": "Element orientation",
                                    "properties": {
                                        "heading": {"type": "number"},
                                        "unit": {"type": "string"}
                                    }
                                },
                                "properties": {
                                    "type": "object",
                                    "description": "Additional element properties",
                                    "additionalProperties": true
                                }
                            }
                        }
                    },
                    "relationships": {
                        "type": "array",
                        "description": "Spatial relationships",
                        "items": {
                            "type": "object",
                            "required": ["type", "elements"],
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["proximity", "containment", "intersection", "alignment"],
                                    "description": "Type of relationship"
                                },
                                "elements": {
                                    "type": "array",
                                    "description": "Related element IDs",
                                    "items": {"type": "string"}
                                },
                                "metrics": {
                                    "type": "object",
                                    "description": "Relationship metrics",
                                    "properties": {
                                        "distance": {
                                            "type": "object",
                                            "properties": {
                                                "value": {"type": "number", "minimum": 0},
                                                "unit": {"type": "string"},
                                                "measurement_type": {"type": "string"}
                                            }
                                        },
                                        "orientation": {
                                            "type": "object",
                                            "properties": {
                                                "relative_angle": {"type": "number"},
                                                "unit": {"type": "string"}
                                            }
                                        },
                                        "clearance": {
                                            "type": "object",
                                            "properties": {
                                                "value": {"type": "number", "minimum": 0},
                                                "unit": {"type": "string"}
                                            }
                                        }
                                    }
                                },
                                "constraints": {
                                    "type": "object",
                                    "description": "Relationship constraints",
                                    "properties": {
                                        "min_distance": {"type": "number", "minimum": 0},
                                        "max_distance": {"type": "number", "minimum": 0},
                                        "required_clearance": {"type": "number", "minimum": 0}
                                    }
                                },
                                "temporal_aspects": {
                                    "type": "object",
                                    "description": "Temporal aspects of the relationship",
                                    "properties": {
                                        "start_time": {
                                            "type": "string",
                                            "format": "date-time"
                                        },
                                        "end_time": {
                                            "type": "string",
                                            "format": "date-time"
                                        },
                                        "duration": {"type": "string"}
                                    }
                                }
                            }
                        }
                    },
                    "environmental_factors": {
                        "type": "array",
                        "description": "Environmental context factors",
                        "items": {
                            "type": "object",
                            "required": ["type"],
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["lighting", "temperature", "humidity", "noise", "air_quality"],
                                    "description": "Type of environmental factor"
                                },
                                "source": {
                                    "type": "object",
                                    "description": "Factor source information",
                                    "properties": {
                                        "type": {"type": "string"},
                                        "direction": {"type": "string"},
                                        "intensity": {"type": "number"},
                                        "unit": {"type": "string"}
                                    }
                                },
                                "distribution": {
                                    "type": "object",
                                    "description": "Spatial distribution",
                                    "properties": {
                                        "type": {"type": "string"},
                                        "pattern": {"type": "string"},
                                        "coverage": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 1
                                        }
                                    }
                                },
                                "affected_elements": {
                                    "type": "array",
                                    "description": "Affected element IDs",
                                    "items": {"type": "string"}
                                },
                                "temporal_variation": {
                                    "type": "object",
                                    "description": "Temporal variation pattern",
                                    "properties": {
                                        "pattern": {"type": "string"},
                                        "peak_time": {"type": "string"},
                                        "variation_range": {
                                            "type": "object",
                                            "properties": {
                                                "min": {"type": "number"},
                                                "max": {"type": "number"},
                                                "unit": {"type": "string"}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "analysis": {
                        "type": "object",
                        "description": "Spatial analysis results",
                        "properties": {
                            "space_utilization": {
                                "type": "object",
                                "description": "Space utilization analysis",
                                "properties": {
                                    "occupied_area": {"type": "number", "minimum": 0},
                                    "total_area": {"type": "number", "minimum": 0},
                                    "utilization_ratio": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1
                                    },
                                    "density_map": {
                                        "type": "object",
                                        "properties": {
                                            "resolution": {"type": "string"},
                                            "data": {
                                                "type": "array",
                                                "items": {
                                                    "type": "array",
                                                    "items": {"type": "number"}
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "accessibility": {
                                "type": "object",
                                "description": "Accessibility analysis",
                                "properties": {
                                    "pathways": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "start": {
                                                    "type": "object",
                                                    "properties": {
                                                        "x": {"type": "number"},
                                                        "y": {"type": "number"}
                                                    }
                                                },
                                                "end": {
                                                    "type": "object",
                                                    "properties": {
                                                        "x": {"type": "number"},
                                                        "y": {"type": "number"}
                                                    }
                                                },
                                                "width": {"type": "number", "minimum": 0},
                                                "clearance_height": {"type": "number", "minimum": 0}
                                            }
                                        }
                                    },
                                    "bottlenecks": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "location": {
                                                    "type": "object",
                                                    "properties": {
                                                        "x": {"type": "number"},
                                                        "y": {"type": "number"}
                                                    }
                                                },
                                                "width": {"type": "number", "minimum": 0},
                                                "risk_level": {
                                                    "type": "string",
                                                    "enum": ["low", "medium", "high"]
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "visibility": {
                                "type": "object",
                                "description": "Visibility analysis",
                                "properties": {
                                    "viewpoints": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "position": {
                                                    "type": "object",
                                                    "properties": {
                                                        "x": {"type": "number"},
                                                        "y": {"type": "number"}
                                                    }
                                                },
                                                "direction": {"type": "number"},
                                                "field_of_view": {
                                                    "type": "number",
                                                    "minimum": 0,
                                                    "maximum": 360
                                                }
                                            }
                                        }
                                    },
                                    "occlusions": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "blocker_id": {"type": "string"},
                                                "affected_area": {
                                                    "type": "object",
                                                    "properties": {
                                                        "type": {"type": "string"},
                                                        "vertices": {
                                                            "type": "array",
                                                            "items": {
                                                                "type": "array",
                                                                "items": {"type": "number"},
                                                                "minItems": 2,
                                                                "maxItems": 2
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "visualization": {
                        "type": "object",
                        "description": "Visualization parameters",
                        "properties": {
                            "style": {
                                "type": "object",
                                "description": "Visual style settings",
                                "properties": {
                                    "color_scheme": {"type": "string"},
                                    "opacity": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1
                                    },
                                    "line_weight": {"type": "number", "minimum": 0}
                                }
                            },
                            "layers": {
                                "type": "array",
                                "description": "Visualization layers",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "type"],
                                    "properties": {
                                        "name": {"type": "string"},
                                        "type": {"type": "string"},
                                        "visible": {"type": "boolean"},
                                        "z_index": {"type": "integer"}
                                    }
                                }
                            },
                            "annotations": {
                                "type": "array",
                                "description": "Visual annotations",
                                "items": {
                                    "type": "object",
                                    "required": ["type", "content"],
                                    "properties": {
                                        "type": {"type": "string"},
                                        "content": {"type": "string"},
                                        "position": {
                                            "type": "object",
                                            "properties": {
                                                "x": {"type": "number"},
                                                "y": {"type": "number"}
                                            }
                                        },
                                        "style": {
                                            "type": "object",
                                            "properties": {
                                                "font_size": {"type": "number"},
                                                "color": {"type": "string"}
                                            }
                                        }
                                    }
                                }
                            },
                            "viewport": {
                                "type": "object",
                                "description": "Viewport settings",
                                "properties": {
                                    "center": {
                                        "type": "object",
                                        "properties": {
                                            "x": {"type": "number"},
                                            "y": {"type": "number"}
                                        }
                                    },
                                    "zoom": {"type": "number", "minimum": 0},
                                    "rotation": {"type": "number"}
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the spatial relation",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the spatial relation"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Schema version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "archived", "deprecated"],
                                "description": "Status of the spatial relation"
                            },
                            "accuracy_level": {
                                "type": "string",
                                "enum": ["low", "medium", "high"],
                                "description": "Overall accuracy level"
                            },
                            "data_sources": {
                                "type": "array",
                                "description": "Data sources used",
                                "items": {"type": "string"}
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