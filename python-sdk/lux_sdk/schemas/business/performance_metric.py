"""
Performance Metric Schema

This schema defines the structure for business performance metrics,
including KPIs, targets, and performance tracking.
"""

from lux_sdk.signals import SignalSchema

PerformanceMetricSchema = SignalSchema(
    name="performance_metric",
    version="1.0",
    description="Schema for tracking business performance metrics",
    schema={
        "type": "object",
        "description": "Schema for business performance metrics",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the metric was recorded"
            },
            "metric_id": {
                "type": "string",
                "description": "Unique identifier for this performance metric"
            },
            "name": {
                "type": "string",
                "description": "Name of the performance metric"
            },
            "category": {
                "type": "string",
                "enum": [
                    "financial",
                    "operational",
                    "customer",
                    "employee",
                    "market",
                    "innovation",
                    "sustainability",
                    "compliance"
                ],
                "description": "Category of the performance metric"
            },
            "measurement": {
                "type": "object",
                "description": "Measurement details of the metric",
                "properties": {
                    "value": {"type": "number"},
                    "unit": {"type": "string"},
                    "frequency": {
                        "type": "string",
                        "enum": ["hourly", "daily", "weekly", "monthly", "quarterly", "annually"]
                    },
                    "calculation_method": {"type": "string"}
                },
                "required": ["value", "unit", "frequency"]
            },
            "targets": {
                "type": "array",
                "description": "Performance targets for the metric",
                "items": {
                    "type": "object",
                    "properties": {
                        "target_value": {"type": "number"},
                        "threshold_type": {
                            "type": "string",
                            "enum": ["minimum", "maximum", "range", "exact"]
                        },
                        "time_frame": {
                            "type": "object",
                            "properties": {
                                "start_date": {"type": "string", "format": "date"},
                                "end_date": {"type": "string", "format": "date"}
                            },
                            "required": ["start_date", "end_date"]
                        },
                        "priority": {
                            "type": "string",
                            "enum": ["critical", "high", "medium", "low"]
                        }
                    },
                    "required": ["target_value", "threshold_type", "time_frame"]
                }
            },
            "trends": {
                "type": "object",
                "description": "Trend analysis of the metric",
                "properties": {
                    "direction": {
                        "type": "string",
                        "enum": ["increasing", "decreasing", "stable", "fluctuating"]
                    },
                    "percentage_change": {"type": "number"},
                    "comparison_period": {
                        "type": "string",
                        "enum": ["previous_day", "previous_week", "previous_month", "previous_quarter", "previous_year"]
                    },
                    "seasonality": {"type": "boolean"}
                }
            },
            "benchmarks": {
                "type": "array",
                "description": "Benchmark comparisons",
                "items": {
                    "type": "object",
                    "properties": {
                        "source": {"type": "string"},
                        "value": {"type": "number"},
                        "date": {"type": "string", "format": "date"},
                        "context": {"type": "string"}
                    },
                    "required": ["source", "value"]
                }
            },
            "dependencies": {
                "type": "array",
                "description": "Dependencies with other metrics",
                "items": {
                    "type": "object",
                    "properties": {
                        "metric_id": {"type": "string"},
                        "relationship_type": {
                            "type": "string",
                            "enum": ["direct", "inverse", "composite", "leading", "lagging"]
                        },
                        "strength": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1
                        }
                    },
                    "required": ["metric_id", "relationship_type"]
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the performance metric",
                "properties": {
                    "owner": {"type": "string"},
                    "data_source": {"type": "string"},
                    "last_updated": {"type": "string", "format": "date-time"},
                    "review_cycle": {
                        "type": "string",
                        "enum": ["daily", "weekly", "monthly", "quarterly"]
                    },
                    "status": {
                        "type": "string",
                        "enum": ["active", "under_review", "deprecated"]
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"}
                    }
                },
                "required": ["owner", "data_source", "last_updated"]
            }
        },
        "required": [
            "timestamp",
            "metric_id",
            "name",
            "category",
            "measurement",
            "targets",
            "metadata"
        ]
    }) 