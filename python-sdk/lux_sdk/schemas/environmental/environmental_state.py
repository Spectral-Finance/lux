"""
EnvironmentalStateSchema

This schema represents environmental state specifications, including
sensor data, object detection, and spatial relationships.
"""

from lux_sdk.signals import SignalSchema

EnvironmentalStateSchema = SignalSchema(
    name="environmental_state",
    version="1.0",
    description="Schema for representing environmental state and sensor data",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "environment_id": {"type": "string", "required": True},
            "name": {"type": "string", "required": True},
            "type": {"type": "string", "enum": ["indoor", "outdoor", "mixed"], "required": True},
            "sensor_data": {
                "type": "object",
                "required": True,
                "properties": {
                    "atmospheric": {
                        "type": "object",
                        "properties": {
                            "temperature": {
                                "type": "object",
                                "properties": {
                                    "value": {"type": "number", "required": True},
                                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit", "kelvin"], "required": True},
                                    "accuracy": {"type": "number"}
                                }
                            },
                            "humidity": {
                                "type": "object",
                                "properties": {
                                    "relative": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                                    "absolute": {"type": "number"},
                                    "accuracy": {"type": "number"}
                                }
                            },
                            "pressure": {
                                "type": "object",
                                "properties": {
                                    "value": {"type": "number", "required": True},
                                    "unit": {"type": "string", "enum": ["hPa", "mbar", "psi"], "required": True},
                                    "accuracy": {"type": "number"}
                                }
                            },
                            "air_quality": {
                                "type": "object",
                                "properties": {
                                    "co2": {"type": "number"},
                                    "tvoc": {"type": "number"},
                                    "pm25": {"type": "number"},
                                    "pm10": {"type": "number"},
                                    "aqi": {"type": "number"}
                                }
                            }
                        }
                    },
                    "light": {
                        "type": "object",
                        "properties": {
                            "intensity": {
                                "type": "object",
                                "properties": {
                                    "value": {"type": "number", "required": True},
                                    "unit": {"type": "string", "enum": ["lux", "foot_candles"], "required": True}
                                }
                            },
                            "color_temperature": {"type": "number"},
                            "spectrum": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "wavelength": {"type": "number"},
                                        "intensity": {"type": "number"}
                                    }
                                }
                            }
                        }
                    },
                    "motion": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "sensor_id": {"type": "string", "required": True},
                                "detected": {"type": "boolean", "required": True},
                                "velocity": {
                                    "type": "object",
                                    "properties": {
                                        "x": {"type": "number"},
                                        "y": {"type": "number"},
                                        "z": {"type": "number"}
                                    }
                                },
                                "timestamp": {"type": "string", "format": "date-time", "required": True}
                            }
                        }
                    }
                }
            },
            "object_detection": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "object_id": {"type": "string", "required": True},
                        "class": {"type": "string", "required": True},
                        "confidence": {"type": "number", "minimum": 0, "maximum": 1, "required": True},
                        "position": {
                            "type": "object",
                            "properties": {
                                "x": {"type": "number", "required": True},
                                "y": {"type": "number", "required": True},
                                "z": {"type": "number"},
                                "orientation": {
                                    "type": "object",
                                    "properties": {
                                        "roll": {"type": "number"},
                                        "pitch": {"type": "number"},
                                        "yaw": {"type": "number"}
                                    }
                                }
                            }
                        },
                        "dimensions": {
                            "type": "object",
                            "properties": {
                                "width": {"type": "number"},
                                "height": {"type": "number"},
                                "depth": {"type": "number"}
                            }
                        },
                        "tracking": {
                            "type": "object",
                            "properties": {
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
                                            "position": {
                                                "type": "object",
                                                "properties": {
                                                    "x": {"type": "number"},
                                                    "y": {"type": "number"},
                                                    "z": {"type": "number"}
                                                }
                                            },
                                            "timestamp": {"type": "string", "format": "date-time"}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "spatial_relationships": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "object1_id": {"type": "string", "required": True},
                        "object2_id": {"type": "string", "required": True},
                        "relationship": {"type": "string", "enum": ["above", "below", "left_of", "right_of", "in_front_of", "behind", "inside", "contains"], "required": True},
                        "distance": {
                            "type": "object",
                            "properties": {
                                "value": {"type": "number", "required": True},
                                "unit": {"type": "string", "enum": ["meters", "feet", "pixels"], "required": True}
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "object",
                        "properties": {
                            "latitude": {"type": "number"},
                            "longitude": {"type": "number"},
                            "altitude": {"type": "number"},
                            "reference_system": {"type": "string"}
                        }
                    },
                    "sensors": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "id": {"type": "string"},
                                "type": {"type": "string"},
                                "manufacturer": {"type": "string"},
                                "model": {"type": "string"},
                                "calibration_date": {"type": "string", "format": "date-time"}
                            }
                        }
                    },
                    "last_maintenance": {"type": "string", "format": "date-time"},
                    "tags": {"type": "array", "items": {"type": "string"}}
                }
            }
        }
    }
) 