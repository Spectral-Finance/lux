"""
Object Recognition Schema

This schema defines the structure for object recognition results,
including detected objects, their properties, and spatial relationships.
"""

from lux_sdk.signals import SignalSchema

ObjectRecognitionSchema = SignalSchema(
    name="object_recognition",
    version="1.0",
    description="Schema for object recognition results in environmental contexts",
    schema={
        "type": "object",
        "description": "Schema for object recognition results in environmental contexts",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the object recognition was performed"
            },
            "recognition_id": {
                "type": "string",
                "description": "Unique identifier for this recognition result"
            },
            "source_id": {
                "type": "string",
                "description": "Identifier of the source (camera, sensor, etc.)"
            },
            "detected_objects": {
                "type": "array",
                "description": "List of detected objects",
                "items": {
                    "type": "object",
                    "properties": {
                        "object_id": {"type": "string"},
                        "class": {
                            "type": "string",
                            "description": "Object classification"
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Confidence score of the detection"
                        },
                        "bounding_box": {
                            "type": "object",
                            "properties": {
                                "x": {"type": "number"},
                                "y": {"type": "number"},
                                "width": {"type": "number"},
                                "height": {"type": "number"}
                            },
                            "required": ["x", "y", "width", "height"]
                        },
                        "attributes": {
                            "type": "object",
                            "properties": {
                                "color": {"type": "string"},
                                "size": {"type": "string"},
                                "shape": {"type": "string"},
                                "texture": {"type": "string"},
                                "orientation": {"type": "number"},
                                "custom_attributes": {
                                    "type": "object",
                                    "additionalProperties": True
                                }
                            }
                        },
                        "tracking": {
                            "type": "object",
                            "properties": {
                                "track_id": {"type": "string"},
                                "velocity": {
                                    "type": "object",
                                    "properties": {
                                        "x": {"type": "number"},
                                        "y": {"type": "number"},
                                        "z": {"type": "number"}
                                    }
                                },
                                "trajectory": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "timestamp": {"type": "string", "format": "date-time"},
                                            "position": {
                                                "type": "object",
                                                "properties": {
                                                    "x": {"type": "number"},
                                                    "y": {"type": "number"},
                                                    "z": {"type": "number"}
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "required": ["object_id", "class", "confidence", "bounding_box"]
                }
            },
            "spatial_relationships": {
                "type": "array",
                "description": "Spatial relationships between detected objects",
                "items": {
                    "type": "object",
                    "properties": {
                        "object1_id": {"type": "string"},
                        "object2_id": {"type": "string"},
                        "relationship_type": {
                            "type": "string",
                            "enum": ["above", "below", "left_of", "right_of", "inside", "contains", "near", "far"]
                        },
                        "distance": {"type": "number"},
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1
                        }
                    },
                    "required": ["object1_id", "object2_id", "relationship_type"]
                }
            },
            "scene_context": {
                "type": "object",
                "description": "Context information about the scene",
                "properties": {
                    "environment_type": {"type": "string"},
                    "lighting_conditions": {"type": "string"},
                    "weather_conditions": {"type": "string"},
                    "time_of_day": {"type": "string"},
                    "location": {
                        "type": "object",
                        "properties": {
                            "latitude": {"type": "number"},
                            "longitude": {"type": "number"},
                            "altitude": {"type": "number"}
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the recognition process",
                "properties": {
                    "model_info": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "version": {"type": "string"},
                            "parameters": {"type": "object"}
                        }
                    },
                    "processing_time_ms": {"type": "number"},
                    "hardware_info": {"type": "string"},
                    "calibration_info": {"type": "object"}
                },
                "required": ["model_info", "processing_time_ms"]
            }
        },
        "required": [
            "timestamp",
            "recognition_id",
            "source_id",
            "detected_objects",
            "metadata"
        ]
    }) 