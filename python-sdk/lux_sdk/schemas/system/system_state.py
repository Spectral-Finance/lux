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
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "system_id": {"type": "string", "required": True},
            "name": {"type": "string", "required": True},
            "environment": {"type": "string", "enum": ["development", "staging", "production"], "required": True},
            "resource_utilization": {
                "type": "object",
                "required": True,
                "properties": {
                    "cpu": {
                        "type": "object",
                        "properties": {
                            "usage_percent": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                            "load_average": {
                                "type": "object",
                                "properties": {
                                    "1min": {"type": "number", "required": True},
                                    "5min": {"type": "number", "required": True},
                                    "15min": {"type": "number", "required": True}
                                }
                            },
                            "core_count": {"type": "integer", "minimum": 1, "required": True},
                            "temperature": {"type": "number"}
                        }
                    },
                    "memory": {
                        "type": "object",
                        "properties": {
                            "total": {"type": "integer", "required": True},
                            "used": {"type": "integer", "required": True},
                            "free": {"type": "integer", "required": True},
                            "usage_percent": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                            "swap_usage": {
                                "type": "object",
                                "properties": {
                                    "total": {"type": "integer"},
                                    "used": {"type": "integer"},
                                    "free": {"type": "integer"}
                                }
                            }
                        }
                    },
                    "disk": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "mount_point": {"type": "string", "required": True},
                                "total": {"type": "integer", "required": True},
                                "used": {"type": "integer", "required": True},
                                "free": {"type": "integer", "required": True},
                                "usage_percent": {"type": "number", "minimum": 0, "maximum": 100, "required": True},
                                "io_stats": {
                                    "type": "object",
                                    "properties": {
                                        "reads": {"type": "integer"},
                                        "writes": {"type": "integer"},
                                        "read_bytes": {"type": "integer"},
                                        "write_bytes": {"type": "integer"}
                                    }
                                }
                            }
                        }
                    },
                    "network": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "interface": {"type": "string", "required": True},
                                "bytes_sent": {"type": "integer", "required": True},
                                "bytes_received": {"type": "integer", "required": True},
                                "packets_sent": {"type": "integer", "required": True},
                                "packets_received": {"type": "integer", "required": True},
                                "errors": {"type": "integer"},
                                "drops": {"type": "integer"}
                            }
                        }
                    }
                }
            },
            "performance_metrics": {
                "type": "object",
                "required": True,
                "properties": {
                    "response_time": {
                        "type": "object",
                        "properties": {
                            "average": {"type": "number", "required": True},
                            "p50": {"type": "number", "required": True},
                            "p90": {"type": "number", "required": True},
                            "p95": {"type": "number", "required": True},
                            "p99": {"type": "number", "required": True}
                        }
                    },
                    "throughput": {
                        "type": "object",
                        "properties": {
                            "requests_per_second": {"type": "number", "required": True},
                            "bytes_per_second": {"type": "number", "required": True}
                        }
                    },
                    "error_rate": {
                        "type": "object",
                        "properties": {
                            "total": {"type": "number", "required": True},
                            "by_type": {
                                "type": "object",
                                "patternProperties": {
                                    "^[a-zA-Z_][a-zA-Z0-9_]*$": {"type": "number"}
                                }
                            }
                        }
                    }
                }
            },
            "operational_status": {
                "type": "object",
                "required": True,
                "properties": {
                    "status": {"type": "string", "enum": ["healthy", "degraded", "critical", "maintenance"], "required": True},
                    "uptime": {"type": "number", "required": True},
                    "last_restart": {"type": "string", "format": "date-time"},
                    "active_processes": {"type": "integer", "minimum": 0, "required": True},
                    "active_connections": {"type": "integer", "minimum": 0, "required": True},
                    "alerts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "level": {"type": "string", "enum": ["info", "warning", "error", "critical"], "required": True},
                                "message": {"type": "string", "required": True},
                                "timestamp": {"type": "string", "format": "date-time", "required": True},
                                "component": {"type": "string", "required": True}
                            }
                        }
                    }
                }
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
        }
    }
) 