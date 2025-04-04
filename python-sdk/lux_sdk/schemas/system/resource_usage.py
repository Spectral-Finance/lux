"""
Resource Usage Schema

This schema defines the structure for tracking system resource utilization,
including CPU, memory, storage, and network metrics.
"""

from lux_sdk.signals import SignalSchema

ResourceUsageSchema = SignalSchema(
    name="resource_usage",
    version="1.0",
    description="Schema for tracking system resource utilization",
    schema={
        "type": "object",
        "description": "Schema for tracking system resource utilization",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the resource usage was measured"
            },
            "usage_id": {
                "type": "string",
                "description": "Unique identifier for this resource usage measurement"
            },
            "system_id": {
                "type": "string",
                "description": "Identifier of the system being monitored"
            },
            "cpu_metrics": {
                "type": "object",
                "description": "CPU utilization metrics",
                "properties": {
                    "usage_percentage": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100
                    },
                    "load_average": {
                        "type": "array",
                        "items": {"type": "number"},
                        "minItems": 3,
                        "maxItems": 3,
                        "description": "1, 5, and 15 minute load averages"
                    },
                    "core_usage": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "core_id": {"type": "string"},
                                "usage_percentage": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 100
                                }
                            },
                            "required": ["core_id", "usage_percentage"]
                        }
                    }
                },
                "required": ["usage_percentage", "load_average"]
            },
            "memory_metrics": {
                "type": "object",
                "description": "Memory utilization metrics",
                "properties": {
                    "total_bytes": {"type": "integer"},
                    "used_bytes": {"type": "integer"},
                    "free_bytes": {"type": "integer"},
                    "cached_bytes": {"type": "integer"},
                    "buffer_bytes": {"type": "integer"},
                    "usage_percentage": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100
                    }
                },
                "required": ["total_bytes", "used_bytes", "free_bytes", "usage_percentage"]
            },
            "storage_metrics": {
                "type": "array",
                "description": "Storage utilization metrics for each mount point",
                "items": {
                    "type": "object",
                    "properties": {
                        "mount_point": {"type": "string"},
                        "filesystem_type": {"type": "string"},
                        "total_bytes": {"type": "integer"},
                        "used_bytes": {"type": "integer"},
                        "free_bytes": {"type": "integer"},
                        "usage_percentage": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 100
                        },
                        "inodes_total": {"type": "integer"},
                        "inodes_used": {"type": "integer"}
                    },
                    "required": ["mount_point", "total_bytes", "used_bytes", "usage_percentage"]
                }
            },
            "network_metrics": {
                "type": "object",
                "description": "Network utilization metrics",
                "properties": {
                    "interfaces": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "interface_name": {"type": "string"},
                                "bytes_sent": {"type": "integer"},
                                "bytes_received": {"type": "integer"},
                                "packets_sent": {"type": "integer"},
                                "packets_received": {"type": "integer"},
                                "errors_in": {"type": "integer"},
                                "errors_out": {"type": "integer"},
                                "bandwidth_usage_percentage": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 100
                                }
                            },
                            "required": ["interface_name", "bytes_sent", "bytes_received"]
                        }
                    },
                    "connections": {
                        "type": "object",
                        "properties": {
                            "total": {"type": "integer"},
                            "established": {"type": "integer"},
                            "listening": {"type": "integer"}
                        }
                    }
                },
                "required": ["interfaces"]
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the resource usage measurement",
                "properties": {
                    "collection_method": {"type": "string"},
                    "sampling_interval_seconds": {"type": "number"},
                    "system_info": {
                        "type": "object",
                        "properties": {
                            "os_type": {"type": "string"},
                            "os_version": {"type": "string"},
                            "architecture": {"type": "string"}
                        }
                    }
                },
                "required": ["collection_method", "sampling_interval_seconds"]
            }
        },
        "required": [
            "timestamp",
            "usage_id",
            "system_id",
            "cpu_metrics",
            "memory_metrics",
            "network_metrics",
            "metadata"
        ]
    }) 