"""
Event Detection Schema

This schema defines the structure for environmental event detection,
including event classification, detection methods, and impact assessment.
"""

from lux_sdk.signals import SignalSchema

EventDetectionSchema = SignalSchema(
    name="event_detection",
    version="1.0",
    description="Schema for tracking environmental event detection",
    schema={
        "type": "object",
        "description": "Schema for environmental event detection",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "When the event was detected"
            },
            "event_id": {
                "type": "string",
                "description": "Unique identifier for this event detection"
            },
            "location": {
                "type": "object",
                "description": "Location where the event was detected",
                "properties": {
                    "latitude": {"type": "number"},
                    "longitude": {"type": "number"},
                    "altitude": {"type": "number"},
                    "region": {"type": "string"},
                    "description": {"type": "string"}
                },
                "required": ["latitude", "longitude"]
            },
            "event_type": {
                "type": "string",
                "enum": [
                    "natural_disaster",
                    "weather_event",
                    "pollution_incident",
                    "wildlife_activity",
                    "vegetation_change",
                    "geological_event",
                    "human_activity",
                    "climate_anomaly"
                ],
                "description": "Type of environmental event detected"
            },
            "detection": {
                "type": "object",
                "description": "Details about how the event was detected",
                "properties": {
                    "method": {
                        "type": "string",
                        "enum": [
                            "satellite",
                            "ground_sensor",
                            "aerial_survey",
                            "manual_observation",
                            "automated_monitoring",
                            "citizen_report",
                            "remote_sensing"
                        ]
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence level of the detection"
                    },
                    "detection_time": {"type": "string", "format": "date-time"},
                    "sensor_id": {"type": "string"},
                    "detection_algorithm": {"type": "string"}
                },
                "required": ["method", "confidence"]
            },
            "characteristics": {
                "type": "object",
                "description": "Characteristics of the detected event",
                "properties": {
                    "intensity": {
                        "type": "string",
                        "enum": ["low", "moderate", "high", "severe", "extreme"]
                    },
                    "scale": {
                        "type": "string",
                        "enum": ["local", "regional", "national", "global"]
                    },
                    "duration": {"type": "string"},
                    "measurements": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "parameter": {"type": "string"},
                                "value": {"type": "number"},
                                "unit": {"type": "string"}
                            },
                            "required": ["parameter", "value", "unit"]
                        }
                    }
                },
                "required": ["intensity", "scale"]
            },
            "impact_assessment": {
                "type": "object",
                "description": "Assessment of the event's impact",
                "properties": {
                    "environmental_impact": {
                        "type": "string",
                        "enum": ["negligible", "minor", "moderate", "major", "catastrophic"]
                    },
                    "affected_area_size": {
                        "type": "object",
                        "properties": {
                            "value": {"type": "number"},
                            "unit": {"type": "string"}
                        },
                        "required": ["value", "unit"]
                    },
                    "affected_ecosystems": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "potential_risks": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "risk_type": {"type": "string"},
                                "severity": {"type": "string"},
                                "probability": {"type": "number"}
                            },
                            "required": ["risk_type", "severity"]
                        }
                    }
                },
                "required": ["environmental_impact", "affected_area_size"]
            },
            "response_actions": {
                "type": "array",
                "description": "Actions taken or recommended in response to the event",
                "items": {
                    "type": "object",
                    "properties": {
                        "action_type": {"type": "string"},
                        "priority": {
                            "type": "string",
                            "enum": ["immediate", "high", "medium", "low"]
                        },
                        "status": {
                            "type": "string",
                            "enum": ["planned", "in_progress", "completed", "cancelled"]
                        },
                        "assigned_to": {"type": "string"},
                        "deadline": {"type": "string", "format": "date-time"}
                    },
                    "required": ["action_type", "priority", "status"]
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the event detection",
                "properties": {
                    "detected_by": {"type": "string"},
                    "verified_by": {"type": "string"},
                    "verification_time": {"type": "string", "format": "date-time"},
                    "data_quality": {
                        "type": "string",
                        "enum": ["high", "medium", "low", "uncertain"]
                    },
                    "related_events": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "notes": {"type": "string"}
                },
                "required": ["detected_by", "data_quality"]
            }
        },
        "required": [
            "timestamp",
            "event_id",
            "location",
            "event_type",
            "detection",
            "characteristics",
            "impact_assessment",
            "metadata"
        ]
    }) 