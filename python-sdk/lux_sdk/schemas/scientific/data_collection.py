"""
Scientific Data Collection Schema

This schema represents data collection activities in scientific research,
including experimental measurements, observations, and research protocols.
"""

from lux_sdk.signals import SignalSchema

ScientificDataCollectionSchema = SignalSchema(
    name="scientific_data_collection",
    version="1.0",
    description="Schema for tracking scientific data collection activities and measurements",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "collection_id": {
                "type": "string",
                "description": "Unique identifier for this data collection activity"
            },
            "experiment_id": {
                "type": "string",
                "description": "Reference to the associated experiment"
            },
            "collection_type": {
                "type": "string",
                "enum": ["measurement", "observation", "survey", "simulation", "sample"],
                "description": "Type of scientific data collection"
            },
            "protocol": {
                "type": "object",
                "properties": {
                    "protocol_id": {
                        "type": "string",
                        "description": "Identifier for the collection protocol"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the protocol"
                    },
                    "steps": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "step_number": {
                                    "type": "integer",
                                    "description": "Order of the step"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the step"
                                },
                                "parameters": {
                                    "type": "object",
                                    "description": "Parameters for this step"
                                }
                            },
                            "required": ["step_number", "description"]
                        }
                    }
                },
                "required": ["protocol_id", "version"]
            },
            "measurements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "variable": {
                            "type": "string",
                            "description": "Name of the measured variable"
                        },
                        "value": {
                            "description": "Measured value"
                        },
                        "unit": {
                            "type": "string",
                            "description": "Unit of measurement"
                        },
                        "uncertainty": {
                            "type": "number",
                            "description": "Measurement uncertainty"
                        },
                        "method": {
                            "type": "string",
                            "description": "Method of measurement"
                        },
                        "instrument": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Name of the instrument"
                                },
                                "calibration_date": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Last calibration date"
                                }
                            }
                        }
                    },
                    "required": ["variable", "value", "unit"]
                }
            },
            "conditions": {
                "type": "object",
                "properties": {
                    "environmental": {
                        "type": "object",
                        "properties": {
                            "temperature": {
                                "type": "number",
                                "description": "Temperature in Kelvin"
                            },
                            "pressure": {
                                "type": "number",
                                "description": "Pressure in Pascal"
                            },
                            "humidity": {
                                "type": "number",
                                "description": "Relative humidity percentage"
                            }
                        }
                    },
                    "controls": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "variable": {
                                    "type": "string",
                                    "description": "Controlled variable"
                                },
                                "value": {
                                    "description": "Control value"
                                }
                            },
                            "required": ["variable", "value"]
                        }
                    }
                }
            },
            "quality_control": {
                "type": "object",
                "properties": {
                    "validation_checks": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "check_type": {
                                    "type": "string",
                                    "description": "Type of validation check"
                                },
                                "result": {
                                    "type": "boolean",
                                    "description": "Result of the check"
                                },
                                "notes": {
                                    "type": "string",
                                    "description": "Notes about the check"
                                }
                            },
                            "required": ["check_type", "result"]
                        }
                    },
                    "outliers_detected": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "variable": {
                                    "type": "string",
                                    "description": "Variable with outlier"
                                },
                                "value": {
                                    "description": "Outlier value"
                                },
                                "z_score": {
                                    "type": "number",
                                    "description": "Z-score of the outlier"
                                }
                            },
                            "required": ["variable", "value"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "collector": {
                        "type": "string",
                        "description": "ID of the person/system collecting data"
                    },
                    "location": {
                        "type": "object",
                        "properties": {
                            "facility": {
                                "type": "string",
                                "description": "Research facility name"
                            },
                            "coordinates": {
                                "type": "object",
                                "properties": {
                                    "latitude": {"type": "number"},
                                    "longitude": {"type": "number"}
                                }
                            }
                        }
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes or observations"
                    }
                }
            }
        },
        "required": ["timestamp", "collection_id", "experiment_id", "collection_type", "protocol", "measurements"]
    }
) 