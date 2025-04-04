from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ResearchDataSchema(SignalSchema):
    """Schema for representing scientific research data.
    
    This schema defines the structure for scientific data, including measurements,
    observations, experimental results, and associated metadata. It supports
    various data types and formats common in scientific research.
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "data_id": "data-123456",
            "study_id": "study-789",
            "data_type": "measurement",
            "collection_info": {
                "collector": "researcher-456",
                "location": {
                    "latitude": 37.7749,
                    "longitude": -122.4194,
                    "elevation": 100.5,
                    "description": "Field site A"
                },
                "instrument": {
                    "name": "Spectrometer XYZ",
                    "model": "ABC-123",
                    "calibration_date": "2024-03-01T00:00:00Z",
                    "settings": {
                        "wavelength_range": [400, 700],
                        "resolution": 0.1
                    }
                }
            },
            "measurements": [
                {
                    "timestamp": "2024-04-03T12:34:56Z",
                    "variable": "temperature",
                    "value": 298.15,
                    "unit": "K",
                    "uncertainty": 0.1,
                    "method": "direct_measurement"
                }
            ],
            "derived_data": {
                "calculations": [
                    {
                        "name": "mean_temperature",
                        "value": 298.15,
                        "unit": "K",
                        "method": "arithmetic_mean",
                        "input_measurements": ["temperature"]
                    }
                ],
                "analysis_results": [
                    {
                        "type": "statistical_test",
                        "name": "t_test",
                        "parameters": {
                            "alpha": 0.05,
                            "alternative": "two-sided"
                        },
                        "results": {
                            "statistic": 2.45,
                            "p_value": 0.014,
                            "confidence_interval": [297.9, 298.4]
                        }
                    }
                ]
            },
            "quality_control": {
                "status": "validated",
                "checks_performed": [
                    {
                        "name": "outlier_detection",
                        "result": "pass",
                        "details": {
                            "method": "z_score",
                            "threshold": 3.0
                        }
                    }
                ],
                "flags": [],
                "validation_date": "2024-04-03T13:00:00Z"
            },
            "metadata": {
                "tags": ["temperature", "field_study"],
                "project": "climate_monitoring",
                "data_format_version": "1.0",
                "license": "CC-BY-4.0",
                "related_publications": ["doi:10.1234/example"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="research_data",
            version="1.0",
            description="Schema for scientific research data",
            schema={
                "type": "object",
                "required": ["timestamp", "data_id", "data_type"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the data was recorded"
                    },
                    "data_id": {
                        "type": "string",
                        "description": "Unique identifier for this dataset"
                    },
                    "study_id": {
                        "type": "string",
                        "description": "Identifier of the associated research study"
                    },
                    "data_type": {
                        "type": "string",
                        "enum": ["measurement", "observation", "simulation", "analysis"],
                        "description": "Type of research data"
                    },
                    "collection_info": {
                        "type": "object",
                        "properties": {
                            "collector": {
                                "type": "string",
                                "description": "Identifier of the person or system collecting the data"
                            },
                            "location": {
                                "type": "object",
                                "properties": {
                                    "latitude": {
                                        "type": "number",
                                        "description": "Latitude in decimal degrees"
                                    },
                                    "longitude": {
                                        "type": "number",
                                        "description": "Longitude in decimal degrees"
                                    },
                                    "elevation": {
                                        "type": "number",
                                        "description": "Elevation in meters"
                                    },
                                    "description": {
                                        "type": "string",
                                        "description": "Text description of the location"
                                    }
                                }
                            },
                            "instrument": {
                                "type": "object",
                                "properties": {
                                    "name": {
                                        "type": "string",
                                        "description": "Name of the instrument"
                                    },
                                    "model": {
                                        "type": "string",
                                        "description": "Model number or identifier"
                                    },
                                    "calibration_date": {
                                        "type": "string",
                                        "format": "date-time",
                                        "description": "Last calibration date"
                                    },
                                    "settings": {
                                        "type": "object",
                                        "description": "Instrument-specific settings"
                                    }
                                }
                            }
                        }
                    },
                    "measurements": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["timestamp", "variable", "value", "unit"],
                            "properties": {
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "When the measurement was taken"
                                },
                                "variable": {
                                    "type": "string",
                                    "description": "Name of the measured variable"
                                },
                                "value": {
                                    "type": "number",
                                    "description": "Measured value"
                                },
                                "unit": {
                                    "type": "string",
                                    "description": "Unit of measurement"
                                },
                                "uncertainty": {
                                    "type": "number",
                                    "minimum": 0,
                                    "description": "Measurement uncertainty"
                                },
                                "method": {
                                    "type": "string",
                                    "description": "Measurement method used"
                                }
                            }
                        }
                    },
                    "derived_data": {
                        "type": "object",
                        "properties": {
                            "calculations": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "value", "unit"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Name of the calculated value"
                                        },
                                        "value": {
                                            "type": "number",
                                            "description": "Calculated value"
                                        },
                                        "unit": {
                                            "type": "string",
                                            "description": "Unit of the calculated value"
                                        },
                                        "method": {
                                            "type": "string",
                                            "description": "Calculation method"
                                        },
                                        "input_measurements": {
                                            "type": "array",
                                            "items": {
                                                "type": "string"
                                            },
                                            "description": "Input variables used"
                                        }
                                    }
                                }
                            },
                            "analysis_results": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["type", "name", "results"],
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "description": "Type of analysis"
                                        },
                                        "name": {
                                            "type": "string",
                                            "description": "Name of the analysis"
                                        },
                                        "parameters": {
                                            "type": "object",
                                            "description": "Analysis parameters"
                                        },
                                        "results": {
                                            "type": "object",
                                            "description": "Analysis results"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "quality_control": {
                        "type": "object",
                        "properties": {
                            "status": {
                                "type": "string",
                                "enum": ["raw", "validated", "flagged", "rejected"],
                                "description": "Quality control status"
                            },
                            "checks_performed": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "result"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Name of the quality check"
                                        },
                                        "result": {
                                            "type": "string",
                                            "enum": ["pass", "fail", "warning"],
                                            "description": "Result of the check"
                                        },
                                        "details": {
                                            "type": "object",
                                            "description": "Additional check details"
                                        }
                                    }
                                }
                            },
                            "flags": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Quality control flags"
                            },
                            "validation_date": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When the data was validated"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "tags": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Keywords or tags"
                            },
                            "project": {
                                "type": "string",
                                "description": "Associated project name"
                            },
                            "data_format_version": {
                                "type": "string",
                                "description": "Version of the data format"
                            },
                            "license": {
                                "type": "string",
                                "description": "Data license"
                            },
                            "related_publications": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Related publication DOIs"
                            }
                        }
                    }
                }
            }
        ) 