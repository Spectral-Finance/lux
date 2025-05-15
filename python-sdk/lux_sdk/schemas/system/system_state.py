"""
SystemStateSchema

This schema represents system state specifications, including
resource utilization, performance metrics, and operational status.
"""

from lux_sdk.signals import SignalSchema

SystemStateSchema = SignalSchema(
    name="system_state",
    version="1.0",
    description="Schema for representing system state and operational metrics",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time"},
            "system_id": {"type": "string"},
            "name": {"type": "string"},
            "environment": {"type": "string", "enum": ["development", "staging", "production"]},
            "resource_utilization": {
                "type": "object",
                "properties": {
                    "cpu": {
                        "type": "object",
                        "properties": {
                            "usage_percent": {"type": "number", "minimum": 0, "maximum": 100},
                            "load_average": {
                                "type": "object",
                                "properties": {
                                    "1min": {"type": "number"},
                                    "5min": {"type": "number"},
                                    "15min": {"type": "number"}
                                },
                                "required": ["1min", "5min", "15min"]
                            },
                            "core_count": {"type": "integer", "minimum": 1},
                            "temperature": {"type": "number"}
                        },
                        "required": ["usage_percent", "core_count"]
                    },
                    "memory": {
                        "type": "object",
                        "properties": {
                            "total": {"type": "integer"},
                            "used": {"type": "integer"},
                            "free": {"type": "integer"},
                            "usage_percent": {"type": "number", "minimum": 0, "maximum": 100},
                            "swap_usage": {
                                "type": "object",
                                "properties": {
                                    "total": {"type": "integer"},
                                    "used": {"type": "integer"},
                                    "free": {"type": "integer"}
                                }
                            }
                        },
                        "required": ["total", "used", "free", "usage_percent"]
                    },
                    "disk": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "mount_point": {"type": "string"},
                                "total": {"type": "integer"},
                                "used": {"type": "integer"},
                                "free": {"type": "integer"},
                                "usage_percent": {"type": "number", "minimum": 0, "maximum": 100},
                                "io_stats": {
                                    "type": "object",
                                    "properties": {
                                        "reads": {"type": "integer"},
                                        "writes": {"type": "integer"},
                                        "read_bytes": {"type": "integer"},
                                        "write_bytes": {"type": "integer"}
                                    }
                                }
                            },
                            "required": ["mount_point", "total", "used", "free", "usage_percent"]
                        }
                    },
                    "network": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "interface": {"type": "string"},
                                "bytes_sent": {"type": "integer"},
                                "bytes_received": {"type": "integer"},
                                "packets_sent": {"type": "integer"},
                                "packets_received": {"type": "integer"},
                                "errors": {"type": "integer"},
                                "drops": {"type": "integer"}
                            },
                            "required": ["interface", "bytes_sent", "bytes_received", "packets_sent", "packets_received"]
                        }
                    }
                },
                "required": ["cpu", "memory"]
            },
            "performance_metrics": {
                "type": "object",
                "properties": {
                    "response_time": {
                        "type": "object",
                        "properties": {
                            "average": {"type": "number"},
                            "p50": {"type": "number"},
                            "p90": {"type": "number"},
                            "p95": {"type": "number"},
                            "p99": {"type": "number"}
                        },
                        "required": ["average", "p50", "p90", "p95", "p99"]
                    },
                    "throughput": {
                        "type": "object",
                        "properties": {
                            "requests_per_second": {"type": "number"},
                            "bytes_per_second": {"type": "number"}
                        },
                        "required": ["requests_per_second", "bytes_per_second"]
                    },
                    "error_rate": {
                        "type": "object",
                        "properties": {
                            "total": {"type": "number"},
                            "by_type": {
                                "type": "object",
                                "patternProperties": {
                                    "^[a-zA-Z_][a-zA-Z0-9_]*$": {"type": "number"}
                                }
                            }
                        },
                        "required": ["total"]
                    }
                },
                "required": ["response_time", "throughput", "error_rate"]
            },
            "operational_status": {
                "type": "object",
                "properties": {
                    "status": {"type": "string", "enum": ["healthy", "degraded", "critical", "maintenance"]},
                    "uptime": {"type": "number"},
                    "last_restart": {"type": "string", "format": "date-time"},
                    "active_processes": {"type": "integer", "minimum": 0},
                    "active_connections": {"type": "integer", "minimum": 0},
                    "alerts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "level": {"type": "string", "enum": ["info", "warning", "error", "critical"]},
                                "message": {"type": "string"},
                                "timestamp": {"type": "string", "format": "date-time"},
                                "component": {"type": "string"}
                            },
                            "required": ["level", "message", "timestamp", "component"]
                        }
                    }
                },
                "required": ["status", "uptime", "active_processes", "active_connections"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "version": {"type": "string"},
                    "os_info": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "version": {"type": "string"},
                            "architecture": {"type": "string"}
                        }
                    },
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "location": {"type": "string"},
                    "owner": {"type": "string"},
                    "maintenance_window": {
                        "type": "object",
                        "properties": {
                            "start": {"type": "string", "format": "date-time"},
                            "end": {"type": "string", "format": "date-time"},
                            "frequency": {"type": "string"}
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "system_id", "name", "environment", "resource_utilization", "performance_metrics", "operational_status"]
    }
) 