"""
Schema for environmental sensor data and measurements.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class SensorDataSchema(SignalSchema):
    """Schema for representing sensor data and measurements.
    
    This schema defines the structure for representing sensor readings, including
    sensor information, location, measurements, quality metrics, calibration data,
    alerts, and maintenance records.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "reading_id": "reading_20240403_153000",
            "sensor_id": "sensor_789",
            "sensor_info": {
                "type": "temperature",
                "model": "TempSensor-X1000",
                "manufacturer": "SensorTech",
                "serial_number": "ST-2024-123456",
                "firmware_version": "2.1.0",
                "specifications": {
                    "accuracy": "±0.1°C",
                    "resolution": "0.01°C",
                    "range": "-40°C to 125°C",
                    "response_time": "500ms"
                }
            },
            "location": {
                "latitude": 37.7749,
                "longitude": -122.4194,
                "altitude": 10.5,
                "position_accuracy": 2.5,
                "installation_point": "north_wall",
                "environment": "indoor",
                "zone": "zone_1"
            },
            "measurements": {
                "temperature": {
                    "value": 23.5,
                    "unit": "celsius",
                    "timestamp": "2024-04-03T15:30:00Z",
                    "uncertainty": 0.1,
                    "raw_value": 23.52,
                    "sampling_rate": "1Hz",
                    "aggregation_method": "average",
                    "statistics": {
                        "min": 23.2,
                        "max": 23.8,
                        "mean": 23.5,
                        "std_dev": 0.15
                    }
                },
                "humidity": {
                    "value": 45.2,
                    "unit": "percent",
                    "timestamp": "2024-04-03T15:30:00Z",
                    "uncertainty": 1.0,
                    "raw_value": 45.23,
                    "sampling_rate": "1Hz",
                    "aggregation_method": "average",
                    "statistics": {
                        "min": 44.8,
                        "max": 45.6,
                        "mean": 45.2,
                        "std_dev": 0.2
                    }
                }
            },
            "quality_metrics": {
                "signal_strength": 0.95,
                "noise_level": 0.02,
                "data_quality_score": 0.98,
                "completeness": 1.0,
                "reliability_score": 0.99,
                "validation_status": "passed"
            },
            "calibration": {
                "last_calibration": "2024-01-01T00:00:00Z",
                "calibration_due": "2024-07-01T00:00:00Z",
                "calibration_method": "factory_standard",
                "calibration_certificate": "CAL-2024-123",
                "calibration_factors": {
                    "offset": 0.1,
                    "gain": 1.001
                }
            },
            "alerts": [{
                "type": "threshold_exceeded",
                "severity": "warning",
                "timestamp": "2024-04-03T15:29:55Z",
                "message": "Temperature approaching upper limit",
                "threshold": {
                    "type": "upper",
                    "value": 24.0,
                    "unit": "celsius"
                },
                "status": "active"
            }],
            "maintenance": {
                "last_maintenance": "2024-03-01T10:00:00Z",
                "next_maintenance_due": "2024-06-01T10:00:00Z",
                "maintenance_history": [{
                    "date": "2024-03-01T10:00:00Z",
                    "type": "routine",
                    "actions": ["cleaning", "calibration"],
                    "technician": "tech_123",
                    "notes": "Regular maintenance performed"
                }],
                "status": "operational",
                "lifetime_hours": 2160,
                "power_cycles": 12
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "sensor_system",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "active",
                "tags": ["temperature", "humidity", "indoor"],
                "notes": "Regular operation"
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="sensor_data",
            version="1.0",
            description="Schema for representing sensor data and measurements",
            schema={
                "type": "object",
                "required": ["timestamp", "reading_id", "sensor_id", "sensor_info", "location", "measurements", "quality_metrics"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the sensor reading"
                    },
                    "reading_id": {
                        "type": "string",
                        "description": "Unique identifier for the sensor reading"
                    },
                    "sensor_id": {
                        "type": "string",
                        "description": "Identifier of the sensor"
                    },
                    "sensor_info": {
                        "type": "object",
                        "description": "Sensor information",
                        "required": ["type", "model"],
                        "properties": {
                            "type": {
                                "type": "string",
                                "description": "Type of sensor"
                            },
                            "model": {
                                "type": "string",
                                "description": "Sensor model"
                            },
                            "manufacturer": {
                                "type": "string",
                                "description": "Sensor manufacturer"
                            },
                            "serial_number": {
                                "type": "string",
                                "description": "Serial number"
                            },
                            "firmware_version": {
                                "type": "string",
                                "description": "Firmware version"
                            },
                            "specifications": {
                                "type": "object",
                                "description": "Sensor specifications",
                                "additionalProperties": true
                            }
                        }
                    },
                    "location": {
                        "type": "object",
                        "description": "Sensor location",
                        "required": ["latitude", "longitude"],
                        "properties": {
                            "latitude": {
                                "type": "number",
                                "minimum": -90,
                                "maximum": 90,
                                "description": "Latitude in decimal degrees"
                            },
                            "longitude": {
                                "type": "number",
                                "minimum": -180,
                                "maximum": 180,
                                "description": "Longitude in decimal degrees"
                            },
                            "altitude": {
                                "type": "number",
                                "description": "Altitude in meters"
                            },
                            "position_accuracy": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Position accuracy in meters"
                            },
                            "installation_point": {
                                "type": "string",
                                "description": "Installation point description"
                            },
                            "environment": {
                                "type": "string",
                                "enum": ["indoor", "outdoor", "underwater", "airborne"],
                                "description": "Environmental context"
                            },
                            "zone": {
                                "type": "string",
                                "description": "Zone or area identifier"
                            }
                        }
                    },
                    "measurements": {
                        "type": "object",
                        "description": "Sensor measurements",
                        "additionalProperties": {
                            "type": "object",
                            "required": ["value", "unit", "timestamp"],
                            "properties": {
                                "value": {
                                    "type": "number",
                                    "description": "Measured value"
                                },
                                "unit": {
                                    "type": "string",
                                    "description": "Unit of measurement"
                                },
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Measurement timestamp"
                                },
                                "uncertainty": {
                                    "type": "number",
                                    "minimum": 0,
                                    "description": "Measurement uncertainty"
                                },
                                "raw_value": {
                                    "type": "number",
                                    "description": "Raw sensor value"
                                },
                                "sampling_rate": {
                                    "type": "string",
                                    "description": "Sampling rate"
                                },
                                "aggregation_method": {
                                    "type": "string",
                                    "enum": ["none", "average", "median", "min", "max", "sum"],
                                    "description": "Data aggregation method"
                                },
                                "statistics": {
                                    "type": "object",
                                    "description": "Statistical measures",
                                    "properties": {
                                        "min": {
                                            "type": "number",
                                            "description": "Minimum value"
                                        },
                                        "max": {
                                            "type": "number",
                                            "description": "Maximum value"
                                        },
                                        "mean": {
                                            "type": "number",
                                            "description": "Mean value"
                                        },
                                        "std_dev": {
                                            "type": "number",
                                            "minimum": 0,
                                            "description": "Standard deviation"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "quality_metrics": {
                        "type": "object",
                        "description": "Data quality information",
                        "required": ["data_quality_score"],
                        "properties": {
                            "signal_strength": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Signal strength"
                            },
                            "noise_level": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Noise level"
                            },
                            "data_quality_score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Overall data quality score"
                            },
                            "completeness": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Data completeness"
                            },
                            "reliability_score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Data reliability score"
                            },
                            "validation_status": {
                                "type": "string",
                                "enum": ["pending", "passed", "failed", "unknown"],
                                "description": "Data validation status"
                            }
                        }
                    },
                    "calibration": {
                        "type": "object",
                        "description": "Calibration information",
                        "properties": {
                            "last_calibration": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last calibration timestamp"
                            },
                            "calibration_due": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Next calibration due date"
                            },
                            "calibration_method": {
                                "type": "string",
                                "description": "Calibration method used"
                            },
                            "calibration_certificate": {
                                "type": "string",
                                "description": "Calibration certificate identifier"
                            },
                            "calibration_factors": {
                                "type": "object",
                                "description": "Calibration factors",
                                "additionalProperties": {
                                    "type": "number"
                                }
                            }
                        }
                    },
                    "alerts": {
                        "type": "array",
                        "description": "Sensor alerts and warnings",
                        "items": {
                            "type": "object",
                            "required": ["type", "severity", "timestamp", "message"],
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Alert type"
                                },
                                "severity": {
                                    "type": "string",
                                    "enum": ["info", "warning", "error", "critical"],
                                    "description": "Alert severity"
                                },
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Alert timestamp"
                                },
                                "message": {
                                    "type": "string",
                                    "description": "Alert message"
                                },
                                "threshold": {
                                    "type": "object",
                                    "description": "Threshold information",
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "enum": ["upper", "lower", "range"],
                                            "description": "Threshold type"
                                        },
                                        "value": {
                                            "type": "number",
                                            "description": "Threshold value"
                                        },
                                        "unit": {
                                            "type": "string",
                                            "description": "Threshold unit"
                                        }
                                    }
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["active", "resolved", "acknowledged"],
                                    "description": "Alert status"
                                }
                            }
                        }
                    },
                    "maintenance": {
                        "type": "object",
                        "description": "Maintenance information",
                        "properties": {
                            "last_maintenance": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last maintenance timestamp"
                            },
                            "next_maintenance_due": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Next maintenance due date"
                            },
                            "maintenance_history": {
                                "type": "array",
                                "description": "Maintenance history",
                                "items": {
                                    "type": "object",
                                    "required": ["date", "type", "actions"],
                                    "properties": {
                                        "date": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Maintenance date"
                                        },
                                        "type": {
                                            "type": "string",
                                            "enum": ["routine", "repair", "upgrade", "emergency"],
                                            "description": "Maintenance type"
                                        },
                                        "actions": {
                                            "type": "array",
                                            "description": "Maintenance actions performed",
                                            "items": {"type": "string"}
                                        },
                                        "technician": {
                                            "type": "string",
                                            "description": "Maintenance technician"
                                        },
                                        "notes": {
                                            "type": "string",
                                            "description": "Maintenance notes"
                                        }
                                    }
                                }
                            },
                            "status": {
                                "type": "string",
                                "enum": ["operational", "maintenance_required", "under_maintenance", "faulty"],
                                "description": "Maintenance status"
                            },
                            "lifetime_hours": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Operating hours since installation"
                            },
                            "power_cycles": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Number of power cycles"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the sensor data",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the reading"
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
                                "enum": ["active", "archived", "invalid"],
                                "description": "Data status"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {"type": "string"}
                            },
                            "notes": {
                                "type": "string",
                                "description": "Additional notes"
                            }
                        }
                    }
                }
            }
        ) 