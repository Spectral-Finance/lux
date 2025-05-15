from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class PerformanceMetricsSchema(SignalSchema):
    """Schema for representing performance metrics and measurements.
    
    This schema defines the structure for capturing performance metrics,
    including system metrics, application metrics, and resource utilization.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "metrics_id": "perf_20240403_153000",
            "service_id": "service_789",
            "system_metrics": {
                "cpu": {
                    "usage_percent": 75.5,
                    "load_average": [2.5, 2.1, 1.8],
                    "core_count": 8,
                    "thread_count": 16,
                    "temperature": 65.3
                },
                "memory": {
                    "total_bytes": 17179869184,
                    "used_bytes": 12884901888,
                    "free_bytes": 4294967296,
                    "cached_bytes": 2147483648,
                    "swap_usage_bytes": 1073741824
                },
                "disk": {
                    "read_bytes_sec": 52428800,
                    "write_bytes_sec": 26214400,
                    "iops": 1000,
                    "latency_ms": 5,
                    "utilization_percent": 45.5
                },
                "network": {
                    "rx_bytes_sec": 104857600,
                    "tx_bytes_sec": 52428800,
                    "active_connections": 1000,
                    "error_rate": 0.001,
                    "packet_loss_percent": 0.1
                }
            },
            "application_metrics": {
                "response_time": {
                    "mean_ms": 150,
                    "median_ms": 120,
                    "p95_ms": 250,
                    "p99_ms": 400,
                    "max_ms": 800
                },
                "throughput": {
                    "requests_per_second": 1000,
                    "successful_requests": 980,
                    "failed_requests": 20,
                    "bytes_processed": 104857600
                },
                "concurrency": {
                    "active_users": 500,
                    "active_sessions": 450,
                    "thread_pool_size": 100,
                    "thread_pool_utilization": 0.75
                },
                "error_metrics": {
                    "error_rate": 0.02,
                    "error_count": 20,
                    "error_types": {
                        "client_errors": 15,
                        "server_errors": 5
                    }
                }
            },
            "resource_utilization": {
                "database": {
                    "connections": 100,
                    "active_queries": 50,
                    "query_time_ms": 25,
                    "cache_hit_ratio": 0.85,
                    "deadlocks": 0
                },
                "cache": {
                    "hit_rate": 0.9,
                    "miss_rate": 0.1,
                    "eviction_rate": 0.01,
                    "memory_usage_bytes": 1073741824
                },
                "queue": {
                    "length": 1000,
                    "processing_rate": 100,
                    "wait_time_ms": 50,
                    "consumer_lag": 10
                }
            },
            "custom_metrics": {
                "business_metrics": {
                    "active_transactions": 250,
                    "conversion_rate": 0.15,
                    "revenue_per_second": 100.50
                },
                "feature_usage": {
                    "feature_a_calls": 1000,
                    "feature_b_calls": 800,
                    "feature_c_calls": 600
                }
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "monitoring_system",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "environment": "production",
                "region": "us-west-2",
                "tags": ["performance", "monitoring", "production"],
                "retention_period": "30_days"
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="performance_metrics",
            version="1.0",
            description="Schema for representing performance metrics and measurements",
            schema={
                "type": "object",
                "required": ["timestamp", "metrics_id", "service_id"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the metrics collection"
                    },
                    "metrics_id": {
                        "type": "string",
                        "description": "Unique identifier for the metrics record"
                    },
                    "service_id": {
                        "type": "string",
                        "description": "Identifier of the service being monitored"
                    },
                    "system_metrics": {
                        "type": "object",
                        "description": "System-level performance metrics",
                        "properties": {
                            "cpu": {
                                "type": "object",
                                "description": "CPU metrics",
                                "properties": {
                                    "usage_percent": {
                                        "type": "number",
                                        "description": "CPU usage percentage"
                                    },
                                    "load_average": {
                                        "type": "array",
                                        "description": "Load average over 1, 5, and 15 minutes",
                                        "items": {"type": "number"}
                                    },
                                    "core_count": {
                                        "type": "integer",
                                        "description": "Number of CPU cores"
                                    },
                                    "thread_count": {
                                        "type": "integer",
                                        "description": "Number of CPU threads"
                                    },
                                    "temperature": {
                                        "type": "number",
                                        "description": "CPU temperature in Celsius"
                                    }
                                }
                            },
                            "memory": {
                                "type": "object",
                                "description": "Memory metrics",
                                "properties": {
                                    "total_bytes": {
                                        "type": "integer",
                                        "description": "Total memory in bytes"
                                    },
                                    "used_bytes": {
                                        "type": "integer",
                                        "description": "Used memory in bytes"
                                    },
                                    "free_bytes": {
                                        "type": "integer",
                                        "description": "Free memory in bytes"
                                    },
                                    "cached_bytes": {
                                        "type": "integer",
                                        "description": "Cached memory in bytes"
                                    },
                                    "swap_usage_bytes": {
                                        "type": "integer",
                                        "description": "Swap usage in bytes"
                                    }
                                }
                            },
                            "disk": {
                                "type": "object",
                                "description": "Disk I/O metrics",
                                "properties": {
                                    "read_bytes_sec": {
                                        "type": "integer",
                                        "description": "Disk read bytes per second"
                                    },
                                    "write_bytes_sec": {
                                        "type": "integer",
                                        "description": "Disk write bytes per second"
                                    },
                                    "iops": {
                                        "type": "integer",
                                        "description": "I/O operations per second"
                                    },
                                    "latency_ms": {
                                        "type": "number",
                                        "description": "Disk I/O latency in milliseconds"
                                    },
                                    "utilization_percent": {
                                        "type": "number",
                                        "description": "Disk utilization percentage"
                                    }
                                }
                            },
                            "network": {
                                "type": "object",
                                "description": "Network metrics",
                                "properties": {
                                    "rx_bytes_sec": {
                                        "type": "integer",
                                        "description": "Network receive bytes per second"
                                    },
                                    "tx_bytes_sec": {
                                        "type": "integer",
                                        "description": "Network transmit bytes per second"
                                    },
                                    "active_connections": {
                                        "type": "integer",
                                        "description": "Number of active network connections"
                                    },
                                    "error_rate": {
                                        "type": "number",
                                        "description": "Network error rate"
                                    },
                                    "packet_loss_percent": {
                                        "type": "number",
                                        "description": "Network packet loss percentage"
                                    }
                                }
                            }
                        }
                    },
                    "application_metrics": {
                        "type": "object",
                        "description": "Application-level performance metrics",
                        "properties": {
                            "response_time": {
                                "type": "object",
                                "description": "Response time metrics",
                                "properties": {
                                    "mean_ms": {
                                        "type": "number",
                                        "description": "Mean response time in milliseconds"
                                    },
                                    "median_ms": {
                                        "type": "number",
                                        "description": "Median response time in milliseconds"
                                    },
                                    "p95_ms": {
                                        "type": "number",
                                        "description": "95th percentile response time in milliseconds"
                                    },
                                    "p99_ms": {
                                        "type": "number",
                                        "description": "99th percentile response time in milliseconds"
                                    },
                                    "max_ms": {
                                        "type": "number",
                                        "description": "Maximum response time in milliseconds"
                                    }
                                }
                            },
                            "throughput": {
                                "type": "object",
                                "description": "Throughput metrics",
                                "properties": {
                                    "requests_per_second": {
                                        "type": "number",
                                        "description": "Number of requests per second"
                                    },
                                    "successful_requests": {
                                        "type": "integer",
                                        "description": "Number of successful requests"
                                    },
                                    "failed_requests": {
                                        "type": "integer",
                                        "description": "Number of failed requests"
                                    },
                                    "bytes_processed": {
                                        "type": "integer",
                                        "description": "Number of bytes processed"
                                    }
                                }
                            },
                            "concurrency": {
                                "type": "object",
                                "description": "Concurrency metrics",
                                "properties": {
                                    "active_users": {
                                        "type": "integer",
                                        "description": "Number of active users"
                                    },
                                    "active_sessions": {
                                        "type": "integer",
                                        "description": "Number of active sessions"
                                    },
                                    "thread_pool_size": {
                                        "type": "integer",
                                        "description": "Size of thread pool"
                                    },
                                    "thread_pool_utilization": {
                                        "type": "number",
                                        "description": "Thread pool utilization ratio"
                                    }
                                }
                            },
                            "error_metrics": {
                                "type": "object",
                                "description": "Error metrics",
                                "properties": {
                                    "error_rate": {
                                        "type": "number",
                                        "description": "Error rate"
                                    },
                                    "error_count": {
                                        "type": "integer",
                                        "description": "Total number of errors"
                                    },
                                    "error_types": {
                                        "type": "object",
                                        "description": "Breakdown of error types",
                                        "properties": {
                                            "client_errors": {
                                                "type": "integer",
                                                "description": "Number of client errors"
                                            },
                                            "server_errors": {
                                                "type": "integer",
                                                "description": "Number of server errors"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "resource_utilization": {
                        "type": "object",
                        "description": "Resource utilization metrics",
                        "properties": {
                            "database": {
                                "type": "object",
                                "description": "Database metrics",
                                "properties": {
                                    "connections": {
                                        "type": "integer",
                                        "description": "Number of database connections"
                                    },
                                    "active_queries": {
                                        "type": "integer",
                                        "description": "Number of active queries"
                                    },
                                    "query_time_ms": {
                                        "type": "number",
                                        "description": "Average query time in milliseconds"
                                    },
                                    "cache_hit_ratio": {
                                        "type": "number",
                                        "description": "Cache hit ratio"
                                    },
                                    "deadlocks": {
                                        "type": "integer",
                                        "description": "Number of deadlocks"
                                    }
                                }
                            },
                            "cache": {
                                "type": "object",
                                "description": "Cache metrics",
                                "properties": {
                                    "hit_rate": {
                                        "type": "number",
                                        "description": "Cache hit rate"
                                    },
                                    "miss_rate": {
                                        "type": "number",
                                        "description": "Cache miss rate"
                                    },
                                    "eviction_rate": {
                                        "type": "number",
                                        "description": "Cache eviction rate"
                                    },
                                    "memory_usage_bytes": {
                                        "type": "integer",
                                        "description": "Cache memory usage in bytes"
                                    }
                                }
                            },
                            "queue": {
                                "type": "object",
                                "description": "Queue metrics",
                                "properties": {
                                    "length": {
                                        "type": "integer",
                                        "description": "Queue length"
                                    },
                                    "processing_rate": {
                                        "type": "number",
                                        "description": "Queue processing rate"
                                    },
                                    "wait_time_ms": {
                                        "type": "number",
                                        "description": "Average wait time in milliseconds"
                                    },
                                    "consumer_lag": {
                                        "type": "number",
                                        "description": "Consumer lag"
                                    }
                                }
                            }
                        }
                    },
                    "custom_metrics": {
                        "type": "object",
                        "description": "Custom application-specific metrics",
                        "properties": {
                            "business_metrics": {
                                "type": "object",
                                "description": "Business-related metrics",
                                "additionalProperties": true
                            },
                            "feature_usage": {
                                "type": "object",
                                "description": "Feature usage metrics",
                                "additionalProperties": true
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
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the metrics"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Metrics version"
                            },
                            "environment": {
                                "type": "string",
                                "description": "Environment where metrics were collected"
                            },
                            "region": {
                                "type": "string",
                                "description": "Region where metrics were collected"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {"type": "string"}
                            },
                            "retention_period": {
                                "type": "string",
                                "description": "How long to retain the metrics"
                            }
                        }
                    }
                }
            }
        ) 