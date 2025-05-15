from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ErrorLogSchema(SignalSchema):
    """Schema for representing error logs and diagnostic information.
    
    This schema defines the structure for capturing detailed error information,
    including error details, context, stack traces, and diagnostic data.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "log_id": "error_20240403_153000",
            "service_id": "service_789",
            "error": {
                "type": "RuntimeError",
                "code": "ERR_001",
                "message": "Failed to process image data",
                "severity": "error",
                "category": "data_processing"
            },
            "context": {
                "environment": "production",
                "component": "image_processor",
                "operation": "resize_operation",
                "user_id": "user_123",
                "request_id": "req_456",
                "session_id": "sess_789"
            },
            "stack_trace": {
                "frames": [{
                    "filename": "image_processor.py",
                    "line_number": 123,
                    "function": "resize_image",
                    "code": "result = process_image(image_data)",
                    "variables": {
                        "image_size": "2048x1536",
                        "format": "JPEG"
                    }
                }],
                "raw_trace": "Traceback (most recent call last):\\n...",
                "cause": "Memory allocation failed"
            },
            "system_state": {
                "memory_usage": {
                    "total": 16384,
                    "used": 12288,
                    "free": 4096,
                    "unit": "MB"
                },
                "cpu_usage": {
                    "total": 85.5,
                    "process": 45.2,
                    "unit": "percent"
                },
                "disk_space": {
                    "total": 1024,
                    "used": 768,
                    "free": 256,
                    "unit": "GB"
                }
            },
            "related_errors": [{
                "log_id": "error_20240403_152959",
                "relationship": "caused_by",
                "description": "Previous memory allocation warning"
            }],
            "resolution": {
                "status": "open",
                "priority": "high",
                "assigned_to": "team_devops",
                "steps_taken": [
                    "Initiated memory dump",
                    "Started monitoring process"
                ],
                "next_steps": [
                    "Analyze memory usage pattern",
                    "Implement memory optimization"
                ]
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "error_monitoring_system",
                "last_updated": "2024-04-03T15:35:00Z",
                "version": "1.0",
                "tags": ["memory", "image_processing", "production"],
                "retention_period": "90_days",
                "classification": "operational_error"
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="error_log",
            version="1.0",
            description="Schema for representing error logs and diagnostic information",
            schema={
                "type": "object",
                "required": ["timestamp", "log_id", "service_id", "error"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the error occurrence"
                    },
                    "log_id": {
                        "type": "string",
                        "description": "Unique identifier for the error log"
                    },
                    "service_id": {
                        "type": "string",
                        "description": "Identifier of the service where the error occurred"
                    },
                    "error": {
                        "type": "object",
                        "description": "Core error information",
                        "required": ["type", "message", "severity"],
                        "properties": {
                            "type": {
                                "type": "string",
                                "description": "Type or class of the error"
                            },
                            "code": {
                                "type": "string",
                                "description": "Error code identifier"
                            },
                            "message": {
                                "type": "string",
                                "description": "Error message description"
                            },
                            "severity": {
                                "type": "string",
                                "enum": ["debug", "info", "warning", "error", "critical"],
                                "description": "Severity level of the error"
                            },
                            "category": {
                                "type": "string",
                                "description": "Category or domain of the error"
                            }
                        }
                    },
                    "context": {
                        "type": "object",
                        "description": "Contextual information about the error",
                        "properties": {
                            "environment": {
                                "type": "string",
                                "description": "Environment where the error occurred"
                            },
                            "component": {
                                "type": "string",
                                "description": "Component or module where the error occurred"
                            },
                            "operation": {
                                "type": "string",
                                "description": "Operation being performed when the error occurred"
                            },
                            "user_id": {
                                "type": "string",
                                "description": "ID of the user affected by the error"
                            },
                            "request_id": {
                                "type": "string",
                                "description": "ID of the request that triggered the error"
                            },
                            "session_id": {
                                "type": "string",
                                "description": "ID of the session where the error occurred"
                            }
                        }
                    },
                    "stack_trace": {
                        "type": "object",
                        "description": "Stack trace information",
                        "properties": {
                            "frames": {
                                "type": "array",
                                "description": "Stack frames",
                                "items": {
                                    "type": "object",
                                    "required": ["filename", "line_number", "function"],
                                    "properties": {
                                        "filename": {
                                            "type": "string",
                                            "description": "Name of the file"
                                        },
                                        "line_number": {
                                            "type": "integer",
                                            "description": "Line number in the file"
                                        },
                                        "function": {
                                            "type": "string",
                                            "description": "Function name"
                                        },
                                        "code": {
                                            "type": "string",
                                            "description": "Code snippet"
                                        },
                                        "variables": {
                                            "type": "object",
                                            "description": "Local variables at this frame",
                                            "additionalProperties": true
                                        }
                                    }
                                }
                            },
                            "raw_trace": {
                                "type": "string",
                                "description": "Raw stack trace string"
                            },
                            "cause": {
                                "type": "string",
                                "description": "Root cause of the error"
                            }
                        }
                    },
                    "system_state": {
                        "type": "object",
                        "description": "System state at the time of error",
                        "properties": {
                            "memory_usage": {
                                "type": "object",
                                "description": "Memory usage statistics",
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "description": "Total memory"
                                    },
                                    "used": {
                                        "type": "number",
                                        "description": "Used memory"
                                    },
                                    "free": {
                                        "type": "number",
                                        "description": "Free memory"
                                    },
                                    "unit": {
                                        "type": "string",
                                        "description": "Memory unit"
                                    }
                                }
                            },
                            "cpu_usage": {
                                "type": "object",
                                "description": "CPU usage statistics",
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "description": "Total CPU usage"
                                    },
                                    "process": {
                                        "type": "number",
                                        "description": "Process CPU usage"
                                    },
                                    "unit": {
                                        "type": "string",
                                        "description": "CPU usage unit"
                                    }
                                }
                            },
                            "disk_space": {
                                "type": "object",
                                "description": "Disk space statistics",
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "description": "Total disk space"
                                    },
                                    "used": {
                                        "type": "number",
                                        "description": "Used disk space"
                                    },
                                    "free": {
                                        "type": "number",
                                        "description": "Free disk space"
                                    },
                                    "unit": {
                                        "type": "string",
                                        "description": "Disk space unit"
                                    }
                                }
                            }
                        }
                    },
                    "related_errors": {
                        "type": "array",
                        "description": "Related error logs",
                        "items": {
                            "type": "object",
                            "required": ["log_id", "relationship"],
                            "properties": {
                                "log_id": {
                                    "type": "string",
                                    "description": "ID of the related error log"
                                },
                                "relationship": {
                                    "type": "string",
                                    "enum": ["caused_by", "caused", "related_to", "similar_to"],
                                    "description": "Type of relationship"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the relationship"
                                }
                            }
                        }
                    },
                    "resolution": {
                        "type": "object",
                        "description": "Error resolution information",
                        "properties": {
                            "status": {
                                "type": "string",
                                "enum": ["open", "in_progress", "resolved", "closed", "wont_fix"],
                                "description": "Resolution status"
                            },
                            "priority": {
                                "type": "string",
                                "enum": ["low", "medium", "high", "critical"],
                                "description": "Resolution priority"
                            },
                            "assigned_to": {
                                "type": "string",
                                "description": "Team or person assigned to resolve"
                            },
                            "steps_taken": {
                                "type": "array",
                                "description": "Steps taken to resolve",
                                "items": {"type": "string"}
                            },
                            "next_steps": {
                                "type": "array",
                                "description": "Planned next steps",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the error log",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the log"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Log version"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {"type": "string"}
                            },
                            "retention_period": {
                                "type": "string",
                                "description": "How long to retain the log"
                            },
                            "classification": {
                                "type": "string",
                                "description": "Error classification"
                            }
                        }
                    }
                }
            }
        ) 