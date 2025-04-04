"""
System Health Schema

This schema represents system health metrics, diagnostics, and monitoring data,
including performance metrics, resource utilization, and health indicators.
"""

from lux_sdk.signals import SignalSchema

SystemHealthSchema = SignalSchema(
    name="system_health",
    version="1.0",
    description="Schema for monitoring and analyzing system health metrics",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "system_id": {
                "type": "string",
                "description": "Unique identifier for the system"
            },
            "system_info": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "System name"
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
                        "enum": ["development", "staging", "production"],
                        "description": "Deployment environment"
                    }
                },
                "required": ["name", "type", "version"]
            },
            "health_status": {
                "type": "string",
                "enum": ["healthy", "degraded", "critical", "unknown"],
                "description": "Overall health status"
            },
            "performance_metrics": {
                "type": "object",
                "properties": {
                    "cpu": {
                        "type": "object",
                        "properties": {
                            "utilization": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "CPU utilization percentage"
                            },
                            "load_average": {
                                "type": "array",
                                "items": {
                                    "type": "number",
                                    "description": "Load average values (1m, 5m, 15m)"
                                },
                                "minItems": 3,
                                "maxItems": 3
                            },
                            "temperature": {
                                "type": "number",
                                "description": "CPU temperature in Celsius"
                            }
                        },
                        "required": ["utilization"]
                    },
                    "memory": {
                        "type": "object",
                        "properties": {
                            "total": {
                                "type": "number",
                                "description": "Total memory in bytes"
                            },
                            "used": {
                                "type": "number",
                                "description": "Used memory in bytes"
                            },
                            "free": {
                                "type": "number",
                                "description": "Free memory in bytes"
                            },
                            "swap_usage": {
                                "type": "number",
                                "description": "Swap usage in bytes"
                            }
                        },
                        "required": ["total", "used", "free"]
                    },
                    "disk": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "mount_point": {
                                    "type": "string",
                                    "description": "Disk mount point"
                                },
                                "total": {
                                    "type": "number",
                                    "description": "Total space in bytes"
                                },
                                "used": {
                                    "type": "number",
                                    "description": "Used space in bytes"
                                },
                                "free": {
                                    "type": "number",
                                    "description": "Free space in bytes"
                                },
                                "io_stats": {
                                    "type": "object",
                                    "properties": {
                                        "reads": {
                                            "type": "number",
                                            "description": "Number of read operations"
                                        },
                                        "writes": {
                                            "type": "number",
                                            "description": "Number of write operations"
                                        }
                                    }
                                }
                            },
                            "required": ["mount_point", "total", "used", "free"]
                        }
                    },
                    "network": {
                        "type": "object",
                        "properties": {
                            "interfaces": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Interface name"
                                        },
                                        "bytes_sent": {
                                            "type": "number",
                                            "description": "Bytes sent"
                                        },
                                        "bytes_received": {
                                            "type": "number",
                                            "description": "Bytes received"
                                        },
                                        "errors": {
                                            "type": "number",
                                            "description": "Number of errors"
                                        }
                                    },
                                    "required": ["name", "bytes_sent", "bytes_received"]
                                }
                            },
                            "connections": {
                                "type": "number",
                                "description": "Number of active connections"
                            }
                        }
                    }
                },
                "required": ["cpu", "memory"]
            },
            "services": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "service_id": {
                            "type": "string",
                            "description": "Service identifier"
                        },
                        "name": {
                            "type": "string",
                            "description": "Service name"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["running", "stopped", "degraded", "unknown"],
                            "description": "Service status"
                        },
                        "uptime": {
                            "type": "number",
                            "description": "Service uptime in seconds"
                        },
                        "metrics": {
                            "type": "object",
                            "description": "Service-specific metrics"
                        }
                    },
                    "required": ["service_id", "name", "status"]
                }
            },
            "alerts": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "alert_id": {
                            "type": "string",
                            "description": "Alert identifier"
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
                        "component": {
                            "type": "string",
                            "description": "Affected component"
                        },
                        "timestamp": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When the alert was generated"
                        }
                    },
                    "required": ["alert_id", "severity", "message", "timestamp"]
                }
            },
            "diagnostics": {
                "type": "object",
                "properties": {
                    "error_logs": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time"
                                },
                                "level": {
                                    "type": "string",
                                    "enum": ["debug", "info", "warning", "error", "critical"]
                                },
                                "message": {
                                    "type": "string"
                                },
                                "stack_trace": {
                                    "type": "string"
                                }
                            },
                            "required": ["timestamp", "level", "message"]
                        }
                    },
                    "system_checks": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "check_name": {
                                    "type": "string",
                                    "description": "Name of the diagnostic check"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["pass", "fail", "warning"],
                                    "description": "Check status"
                                },
                                "details": {
                                    "type": "string",
                                    "description": "Additional details"
                                }
                            },
                            "required": ["check_name", "status"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "collection_method": {
                        "type": "string",
                        "description": "How metrics were collected"
                    },
                    "collection_interval": {
                        "type": "number",
                        "description": "Collection interval in seconds"
                    },
                    "agent_version": {
                        "type": "string",
                        "description": "Version of collection agent"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "system_id", "system_info", "health_status", "performance_metrics"]
    }
) 