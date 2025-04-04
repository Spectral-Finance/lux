"""
Schema for system performance metrics and monitoring.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class PerformanceMetricsSchema(SignalSchema):
    """Schema for system performance metrics and monitoring.
    
    This schema defines the structure for capturing and analyzing system performance
    metrics, including resource utilization, key performance indicators, and alerts.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "metrics_id": "perf_20240403_153000",
            "system_id": "sys_789",
            "system_info": {
                "name": "web_server_01",
                "type": "application_server",
                "version": "2.1.0",
                "environment": "production"
            },
            "resource_utilization": {
                "cpu": {
                    "usage_percent": 75.5,
                    "load_average": [0.75, 0.65, 0.80],
                    "core_metrics": [{
                        "core_id": "cpu_0",
                        "usage": 80.5,
                        "temperature": 65.3
                    }]
                },
                "memory": {
                    "total": 16384,
                    "used": 12288,
                    "free": 4096,
                    "swap_usage": 1024
                },
                "disk": {
                    "total_space": 1024000,
                    "used_space": 768000,
                    "free_space": 256000,
                    "io_operations": {
                        "reads": 1500,
                        "writes": 500
                    }
                },
                "network": {
                    "bandwidth_usage": 75.5,
                    "throughput": 1000,
                    "latency": 50,
                    "packet_loss": 0.1
                }
            },
            "performance_indicators": {
                "response_time": {
                    "average": 150,
                    "percentiles": {
                        "p50": 125,
                        "p90": 200,
                        "p99": 300
                    },
                    "max": 500
                },
                "throughput": {
                    "requests_per_second": 1000,
                    "transactions_per_second": 800,
                    "data_transfer_rate": 5000
                },
                "error_rate": {
                    "total_errors": 50,
                    "error_percentage": 0.5,
                    "error_types": {
                        "timeout": 20,
                        "validation": 15,
                        "system": 15
                    }
                }
            },
            "availability": {
                "uptime": 864000,
                "downtime": 300,
                "availability_percentage": 99.965,
                "maintenance_windows": [{
                    "start_time": "2024-04-03T02:00:00Z",
                    "end_time": "2024-04-03T04:00:00Z",
                    "type": "scheduled_maintenance"
                }]
            },
            "alerts": [{
                "alert_id": "alert_123",
                "type": "high_cpu_usage",
                "severity": "warning",
                "message": "CPU usage above 75%",
                "timestamp": "2024-04-03T15:25:00Z"
            }],
            "thresholds": {
                "cpu_threshold": 80,
                "memory_threshold": 85,
                "disk_threshold": 90,
                "network_threshold": 75
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "updated_at": "2024-04-03T15:30:00Z",
                "collection_method": "agent_based",
                "sampling_rate": "1m",
                "version": "1.0",
                "tags": [
                    "production",
                    "web_server",
                    "performance"
                ]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="performance_metrics",
            version="1.0",
            description="Schema for tracking and analyzing system performance metrics",
            schema={
                "type": "object",
                "required": ["timestamp", "metrics_id", "system_id", "system_info", "resource_utilization", "performance_indicators"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the performance metrics"
                    },
                    "metrics_id": {
                        "type": "string",
                        "description": "Unique identifier for the metrics record"
                    },
                    "system_id": {
                        "type": "string",
                        "description": "Identifier of the monitored system"
                    },
                    "system_info": {
                        "type": "object",
                        "description": "System information",
                        "required": ["name", "type"],
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Name of the system"
                            },
                            "type": {
                                "type": "string",
                                "description": "Type of system"
                            },
                            "version": {
                                "type": "string",
                                "description": "System version"
                            },
                            "environment": {
                                "type": "string",
                                "enum": ["development", "testing", "staging", "production"],
                                "description": "Operating environment"
                            }
                        }
                    },
                    "resource_utilization": {
                        "type": "object",
                        "description": "Resource utilization metrics",
                        "required": ["cpu", "memory"],
                        "properties": {
                            "cpu": {
                                "type": "object",
                                "description": "CPU metrics",
                                "required": ["usage_percent"],
                                "properties": {
                                    "usage_percent": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 100,
                                        "description": "CPU usage percentage"
                                    },
                                    "load_average": {
                                        "type": "array",
                                        "description": "Load average values",
                                        "items": {
                                            "type": "number",
                                            "minimum": 0
                                        }
                                    },
                                    "core_metrics": {
                                        "type": "array",
                                        "description": "Per-core metrics",
                                        "items": {
                                            "type": "object",
                                            "required": ["core_id", "usage"],
                                            "properties": {
                                                "core_id": {
                                                    "type": "string",
                                                    "description": "Core identifier"
                                                },
                                                "usage": {
                                                    "type": "number",
                                                    "minimum": 0,
                                                    "maximum": 100,
                                                    "description": "Core usage percentage"
                                                },
                                                "temperature": {
                                                    "type": "number",
                                                    "description": "Core temperature"
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "memory": {
                                "type": "object",
                                "description": "Memory metrics",
                                "required": ["total", "used", "free"],
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Total memory available"
                                    },
                                    "used": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Memory in use"
                                    },
                                    "free": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Free memory available"
                                    },
                                    "swap_usage": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Swap memory usage"
                                    }
                                }
                            },
                            "disk": {
                                "type": "object",
                                "description": "Disk metrics",
                                "properties": {
                                    "total_space": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Total disk space"
                                    },
                                    "used_space": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Used disk space"
                                    },
                                    "free_space": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Free disk space"
                                    },
                                    "io_operations": {
                                        "type": "object",
                                        "description": "I/O operations"
                                    }
                                }
                            },
                            "network": {
                                "type": "object",
                                "description": "Network metrics",
                                "properties": {
                                    "bandwidth_usage": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 100,
                                        "description": "Bandwidth utilization"
                                    },
                                    "throughput": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Network throughput"
                                    },
                                    "latency": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Network latency"
                                    },
                                    "packet_loss": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 100,
                                        "description": "Packet loss rate"
                                    }
                                }
                            }
                        }
                    },
                    "performance_indicators": {
                        "type": "object",
                        "description": "Key performance indicators",
                        "required": ["response_time", "throughput"],
                        "properties": {
                            "response_time": {
                                "type": "object",
                                "description": "Response time metrics",
                                "required": ["average"],
                                "properties": {
                                    "average": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Average response time"
                                    },
                                    "percentiles": {
                                        "type": "object",
                                        "description": "Response time percentiles"
                                    },
                                    "max": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Maximum response time"
                                    }
                                }
                            },
                            "throughput": {
                                "type": "object",
                                "description": "System throughput metrics",
                                "properties": {
                                    "requests_per_second": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Request rate"
                                    },
                                    "transactions_per_second": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Transaction rate"
                                    },
                                    "data_transfer_rate": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Data transfer rate"
                                    }
                                }
                            },
                            "error_rate": {
                                "type": "object",
                                "description": "Error rate metrics",
                                "properties": {
                                    "total_errors": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Total error count"
                                    },
                                    "error_percentage": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 100,
                                        "description": "Error percentage"
                                    },
                                    "error_types": {
                                        "type": "object",
                                        "description": "Breakdown by error type"
                                    }
                                }
                            }
                        }
                    },
                    "availability": {
                        "type": "object",
                        "description": "System availability metrics",
                        "properties": {
                            "uptime": {
                                "type": "number",
                                "minimum": 0,
                                "description": "System uptime in seconds"
                            },
                            "downtime": {
                                "type": "number",
                                "minimum": 0,
                                "description": "System downtime in seconds"
                            },
                            "availability_percentage": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "System availability percentage"
                            },
                            "maintenance_windows": {
                                "type": "array",
                                "description": "Scheduled maintenance periods",
                                "items": {
                                    "type": "object",
                                    "required": ["start_time", "end_time"],
                                    "properties": {
                                        "start_time": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Start of maintenance"
                                        },
                                        "end_time": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "End of maintenance"
                                        },
                                        "type": {
                                            "type": "string",
                                            "description": "Type of maintenance"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "alerts": {
                        "type": "array",
                        "description": "Performance-related alerts",
                        "items": {
                            "type": "object",
                            "required": ["alert_id", "type", "severity"],
                            "properties": {
                                "alert_id": {
                                    "type": "string",
                                    "description": "Alert identifier"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Type of alert"
                                },
                                "severity": {
                                    "type": "string",
                                    "enum": ["info", "warning", "error", "critical"],
                                    "description": "Alert severity"
                                },
                                "message": {
                                    "type": "string",
                                    "description": "Alert message"
                                },
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Alert timestamp"
                                }
                            }
                        }
                    },
                    "thresholds": {
                        "type": "object",
                        "description": "Performance thresholds",
                        "properties": {
                            "cpu_threshold": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "CPU usage threshold"
                            },
                            "memory_threshold": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "Memory usage threshold"
                            },
                            "disk_threshold": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "Disk usage threshold"
                            },
                            "network_threshold": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "Network usage threshold"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the metrics",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "updated_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "collection_method": {
                                "type": "string",
                                "description": "Method of data collection"
                            },
                            "sampling_rate": {
                                "type": "string",
                                "description": "Data sampling rate"
                            },
                            "version": {
                                "type": "string",
                                "description": "Metrics version"
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