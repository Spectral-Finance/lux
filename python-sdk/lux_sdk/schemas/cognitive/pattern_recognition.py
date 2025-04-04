"""
PatternRecognition Schema

This schema defines the structure for representing pattern recognition and analysis processes.
It's particularly useful for:
- Data pattern identification
- Behavioral pattern analysis
- Trend detection
- Anomaly identification
- Pattern matching and classification

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.cognitive.pattern_recognition import PatternRecognitionSchema

# Create a pattern recognition analysis
signal = Signal(
    schema=PatternRecognitionSchema,
    payload={
        "context": "Network traffic analysis",
        "data_source": {
            "type": "time_series",
            "description": "Server request logs",
            "time_range": {
                "start": "2024-03-01T00:00:00Z",
                "end": "2024-03-15T23:59:59Z"
            },
            "sample_size": 50000
        },
        "identified_patterns": [
            {
                "name": "Daily Usage Spike",
                "type": "temporal",
                "description": "Consistent traffic increase during business hours",
                "frequency": "daily",
                "characteristics": [
                    "Peaks between 13:00-15:00 UTC",
                    "30-40% higher than baseline",
                    "Gradual ramp-up pattern"
                ],
                "confidence": 0.95,
                "supporting_metrics": {
                    "average_peak_duration": "2.5 hours",
                    "average_intensity": "35% above baseline",
                    "consistency_score": 0.92
                }
            },
            {
                "name": "API Usage Pattern",
                "type": "behavioral",
                "description": "Sequential API call pattern indicating automated scripts",
                "characteristics": [
                    "Fixed interval between calls",
                    "Consistent payload structure",
                    "Predictable resource access pattern"
                ],
                "confidence": 0.88,
                "supporting_metrics": {
                    "sequence_consistency": 0.94,
                    "interval_variance": "1.2s"
                }
            }
        ],
        "analysis_methods": [
            {
                "name": "Time Series Decomposition",
                "description": "Separated seasonal, trend, and residual components",
                "parameters": {
                    "window_size": "24h",
                    "seasonality": "daily"
                }
            },
            {
                "name": "Clustering Analysis",
                "description": "K-means clustering on request patterns",
                "parameters": {
                    "n_clusters": 5,
                    "features": ["timestamp", "request_type", "payload_size"]
                }
            }
        ],
        "anomalies": [
            {
                "timestamp": "2024-03-10T18:30:00Z",
                "description": "Unexpected traffic spike outside normal pattern",
                "severity": 0.75,
                "deviation_metrics": {
                    "standard_deviations": 3.5,
                    "magnitude": "200% above baseline"
                }
            }
        ],
        "pattern_relationships": [
            {
                "pattern_pair": ["Daily Usage Spike", "API Usage Pattern"],
                "relationship_type": "correlation",
                "strength": 0.65,
                "description": "API usage increases during daily traffic spikes"
            }
        ],
        "confidence_metrics": {
            "overall_confidence": 0.91,
            "pattern_stability": 0.88,
            "data_quality": 0.95
        },
        "recommendations": [
            {
                "action": "Adjust auto-scaling thresholds",
                "rationale": "Based on consistent daily traffic pattern",
                "priority": 0.85
            },
            {
                "action": "Implement rate limiting for automated API calls",
                "rationale": "To manage consistent bot-like traffic patterns",
                "priority": 0.75
            }
        ]
    }
)
```

Schema Structure:
- context: Description of the analysis context
- data_source: Information about the data being analyzed
- identified_patterns: Array of recognized patterns
  - name: Pattern identifier
  - type: Pattern type (temporal, behavioral, etc.)
  - characteristics: Key pattern features
  - confidence: Confidence in pattern recognition
  - supporting_metrics: Quantitative evidence
- analysis_methods: Methods used to identify patterns
- anomalies: Deviations from recognized patterns
- pattern_relationships: Relationships between patterns
- confidence_metrics: Overall confidence measures
- recommendations: Suggested actions based on patterns

The schema enforces:
- Valid confidence scores
- Required pattern attributes
- Structured analysis methods
- Temporal consistency in data ranges
"""

from lux_sdk.signals import SignalSchema

SCHEMA = {
    "type": "object",
    "properties": {
        "context": {
            "type": "string",
            "description": "Description of the analysis context"
        },
        "data_source": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "enum": ["time_series", "event_log", "spatial", "categorical", "numerical"],
                    "description": "Type of data being analyzed"
                },
                "description": {
                    "type": "string",
                    "description": "Description of the data source"
                },
                "time_range": {
                    "type": "object",
                    "properties": {
                        "start": {
                            "type": "string",
                            "format": "date-time",
                            "description": "Start of the analysis period"
                        },
                        "end": {
                            "type": "string",
                            "format": "date-time",
                            "description": "End of the analysis period"
                        }
                    },
                    "required": ["start", "end"],
                    "additionalProperties": False
                },
                "sample_size": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "Number of data points analyzed"
                }
            },
            "required": ["type", "description"],
            "additionalProperties": False
        },
        "identified_patterns": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Pattern identifier"
                    },
                    "type": {
                        "type": "string",
                        "enum": ["temporal", "spatial", "behavioral", "structural", "statistical"],
                        "description": "Type of pattern"
                    },
                    "description": {
                        "type": "string",
                        "description": "Detailed description of the pattern"
                    },
                    "frequency": {
                        "type": "string",
                        "description": "How often the pattern occurs"
                    },
                    "characteristics": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Key features of the pattern"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in pattern recognition"
                    },
                    "supporting_metrics": {
                        "type": "object",
                        "description": "Quantitative evidence supporting the pattern"
                    }
                },
                "required": ["name", "type", "description", "characteristics", "confidence"],
                "additionalProperties": False
            },
            "minItems": 1,
            "description": "Array of recognized patterns"
        },
        "analysis_methods": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the analysis method"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the method"
                    },
                    "parameters": {
                        "type": "object",
                        "description": "Parameters used in the analysis"
                    }
                },
                "required": ["name", "description"],
                "additionalProperties": False
            },
            "description": "Methods used to identify patterns"
        },
        "anomalies": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the anomaly occurred"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the anomaly"
                    },
                    "severity": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Severity of the anomaly"
                    },
                    "deviation_metrics": {
                        "type": "object",
                        "description": "Metrics showing how this deviates from patterns"
                    }
                },
                "required": ["description", "severity"],
                "additionalProperties": False
            },
            "description": "Deviations from recognized patterns"
        },
        "pattern_relationships": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "pattern_pair": {
                        "type": "array",
                        "items": {"type": "string"},
                        "minItems": 2,
                        "maxItems": 2,
                        "description": "Pair of related patterns"
                    },
                    "relationship_type": {
                        "type": "string",
                        "enum": ["correlation", "causation", "sequence", "hierarchy", "similarity"],
                        "description": "Type of relationship"
                    },
                    "strength": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Strength of the relationship"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the relationship"
                    }
                },
                "required": ["pattern_pair", "relationship_type", "strength"],
                "additionalProperties": False
            },
            "description": "Relationships between identified patterns"
        },
        "confidence_metrics": {
            "type": "object",
            "properties": {
                "overall_confidence": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Overall confidence in pattern recognition"
                },
                "pattern_stability": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Stability of identified patterns"
                },
                "data_quality": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Quality of input data"
                }
            },
            "required": ["overall_confidence"],
            "additionalProperties": False
        },
        "recommendations": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "description": "Recommended action"
                    },
                    "rationale": {
                        "type": "string",
                        "description": "Reasoning behind the recommendation"
                    },
                    "priority": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Priority of the recommendation"
                    }
                },
                "required": ["action", "rationale", "priority"],
                "additionalProperties": False
            },
            "description": "Recommended actions based on patterns"
        }
    },
    "required": [
        "context",
        "data_source",
        "identified_patterns",
        "confidence_metrics"
    ],
    "additionalProperties": False
}

PatternRecognitionSchema = SignalSchema(
    name="lux.cognitive.pattern_recognition",
    version="1.0",
    description="Schema for representing pattern recognition and analysis processes",
    schema=SCHEMA
) 