"""
Object Recognition Schema

This schema represents object recognition and detection results,
including detected objects, their properties, and confidence scores.
"""

from lux_sdk.signals import SignalSchema

ObjectRecognitionSchema = SignalSchema(
    name="object_recognition",
    version="1.0",
    description="Schema for object recognition and detection results",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "recognition_id": {
                "type": "string",
                "description": "Unique identifier for this recognition result"
            },
            "source": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "enum": ["image", "video", "point_cloud", "sensor_data"],
                        "description": "Type of input source"
                    },
                    "format": {
                        "type": "string",
                        "description": "Format of the source data"
                    },
                    "dimensions": {
                        "type": "object",
                        "properties": {
                            "width": {
                                "type": "number",
                                "description": "Width of input"
                            },
                            "height": {
                                "type": "number",
                                "description": "Height of input"
                            },
                            "depth": {
                                "type": "number",
                                "description": "Depth of input (if applicable)"
                            }
                        },
                        "required": ["width", "height"]
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "capture_time": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When the source was captured"
                            },
                            "device_info": {
                                "type": "string",
                                "description": "Capturing device information"
                            },
                            "location": {
                                "type": "object",
                                "properties": {
                                    "latitude": {
                                        "type": "number",
                                        "description": "Latitude coordinate"
                                    },
                                    "longitude": {
                                        "type": "number",
                                        "description": "Longitude coordinate"
                                    },
                                    "altitude": {
                                        "type": "number",
                                        "description": "Altitude (if applicable)"
                                    }
                                }
                            }
                        }
                    }
                },
                "required": ["type", "format"]
            },
            "detected_objects": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "object_id": {
                            "type": "string",
                            "description": "Unique identifier for detected object"
                        },
                        "class": {
                            "type": "string",
                            "description": "Object class/category"
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Confidence score"
                        },
                        "bounding_box": {
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
                                "width": {
                                    "type": "number",
                                    "description": "Width of box"
                                },
                                "height": {
                                    "type": "number",
                                    "description": "Height of box"
                                }
                            },
                            "required": ["x", "y", "width", "height"]
                        },
                        "segmentation_mask": {
                            "type": "object",
                            "properties": {
                                "format": {
                                    "type": "string",
                                    "description": "Format of mask data"
                                },
                                "data": {
                                    "type": "string",
                                    "description": "Encoded mask data"
                                }
                            }
                        },
                        "attributes": {
                            "type": "object",
                            "properties": {
                                "color": {
                                    "type": "string",
                                    "description": "Dominant color"
                                },
                                "size": {
                                    "type": "string",
                                    "enum": ["small", "medium", "large"],
                                    "description": "Relative size"
                                },
                                "pose": {
                                    "type": "object",
                                    "properties": {
                                        "orientation": {
                                            "type": "string",
                                            "description": "Object orientation"
                                        },
                                        "position": {
                                            "type": "object",
                                            "properties": {
                                                "x": {
                                                    "type": "number",
                                                    "description": "X position"
                                                },
                                                "y": {
                                                    "type": "number",
                                                    "description": "Y position"
                                                },
                                                "z": {
                                                    "type": "number",
                                                    "description": "Z position"
                                                }
                                            }
                                        }
                                    }
                                },
                                "custom_attributes": {
                                    "type": "object",
                                    "description": "Additional custom attributes"
                                }
                            }
                        },
                        "tracking": {
                            "type": "object",
                            "properties": {
                                "track_id": {
                                    "type": "string",
                                    "description": "Tracking identifier"
                                },
                                "velocity": {
                                    "type": "object",
                                    "properties": {
                                        "x": {
                                            "type": "number",
                                            "description": "X velocity"
                                        },
                                        "y": {
                                            "type": "number",
                                            "description": "Y velocity"
                                        },
                                        "z": {
                                            "type": "number",
                                            "description": "Z velocity"
                                        }
                                    }
                                },
                                "trajectory": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "timestamp": {
                                                "type": "string",
                                                "format": "date-time"
                                            },
                                            "position": {
                                                "type": "object",
                                                "properties": {
                                                    "x": {
                                                        "type": "number"
                                                    },
                                                    "y": {
                                                        "type": "number"
                                                    },
                                                    "z": {
                                                        "type": "number"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "required": ["object_id", "class", "confidence"]
                }
            },
            "scene_context": {
                "type": "object",
                "properties": {
                    "environment": {
                        "type": "string",
                        "enum": ["indoor", "outdoor", "unknown"],
                        "description": "Environmental context"
                    },
                    "lighting": {
                        "type": "string",
                        "enum": ["bright", "dim", "dark", "unknown"],
                        "description": "Lighting conditions"
                    },
                    "weather": {
                        "type": "string",
                        "description": "Weather conditions (if applicable)"
                    },
                    "time_of_day": {
                        "type": "string",
                        "description": "Time of day"
                    }
                }
            },
            "relationships": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "description": "Type of relationship"
                        },
                        "object_ids": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "IDs of related objects"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of relationship"
                        }
                    },
                    "required": ["type", "object_ids"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "model_info": {
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Name of recognition model"
                            },
                            "version": {
                                "type": "string",
                                "description": "Model version"
                            },
                            "type": {
                                "type": "string",
                                "description": "Type of model"
                            }
                        }
                    },
                    "processing_time": {
                        "type": "number",
                        "description": "Processing time in milliseconds"
                    },
                    "confidence_threshold": {
                        "type": "number",
                        "description": "Minimum confidence threshold"
                    },
                    "settings": {
                        "type": "object",
                        "description": "Recognition settings used"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "recognition_id",
            "source",
            "detected_objects"
        ]
    }
) 