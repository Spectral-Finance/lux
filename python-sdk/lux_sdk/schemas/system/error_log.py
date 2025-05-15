"""
Schema for representing system error logs and diagnostics.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ErrorLogSchema(SignalSchema):
    """Schema for representing system error logs and diagnostics.
    
    This schema defines the structure for capturing and analyzing system errors,
    including their context, impact, and resolution.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "error_id": "err_20240403_153000",
            "system_id": "sys_789",
            "error_context": {
                "component": "authentication_service",
                "environment": {
                    "environment_type": "production",
                    "host": "auth-server-01",
                    "process_id": "12345",
                    "thread_id": "thread-789",
                    "user_id": "user_123"
                },
                "session": {
                    "session_id": "sess_456",
                    "start_time": "2024-04-03T15:00:00Z",
                    "user_agent": "Mozilla/5.0...",
                    "ip_address": "192.168.1.1"
                }
            },
            "error_details": {
                "error_type": "AuthenticationError",
                "error_code": "AUTH_001",
                "severity": "high",
                "message": "Failed to authenticate user",
                "stack_trace": [{
                    "file": "auth_service.py",
                    "line": 123,
                    "function": "authenticate_user",
                    "code": "raise AuthenticationError"
                }],
                "cause": {
                    "type": "TokenExpired",
                    "description": "User token has expired",
                    "chain": [
                        "Token validation failed",
                        "Token expiration check failed"
                    ]
                }
            },
            "system_state": {
                "memory": {
                    "total": 16384,
                    "used": 12288,
                    "free": 4096,
                    "heap": {
                        "size": 8192,
                        "used": 6144
                    }
                },
                "cpu": {
                    "usage": 85.5,
                    "load": [0.75, 0.65, 0.80]
                },
                "disk": {
                    "total": 1024000,
                    "used": 768000,
                    "free": 256000
                },
                "network": {
                    "connections": 1250,
                    "throughput": {
                        "in": 1024,
                        "out": 2048
                    }
                }
            },
            "related_events": [{
                "event_id": "evt_789",
                "timestamp": "2024-04-03T15:29:55Z",
                "type": "TokenValidation",
                "description": "Token validation attempt",
                "correlation": "direct_cause"
            }],
            "impact_analysis": {
                "affected_services": [{
                    "service_id": "auth_service",
                    "impact_level": "high",
                    "users_affected": 150,
                    "business_impact": "User login disruption"
                }],
                "data_integrity": {
                    "corrupted": false,
                    "lost": false,
                    "affected_records": 0
                },
                "performance_impact": {
                    "latency_increase": 250,
                    "throughput_decrease": 30,
                    "resource_consumption": {
                        "cpu_increase": 15,
                        "memory_increase": 200
                    }
                }
            },
            "resolution": {
                "status": "resolved",
                "action_taken": "Token refresh mechanism updated",
                "resolution_time": "PT15M",
                "mitigation_steps": [{
                    "step": "Identify expired tokens",
                    "timestamp": "2024-04-03T15:35:00Z",
                    "outcome": "completed"
                }],
                "prevention": [{
                    "measure": "Proactive token refresh",
                    "implementation": "Automatic refresh at 80% of lifetime",
                    "effectiveness": "high"
                }]
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "system_monitor",
                "last_updated": "2024-04-03T15:45:00Z",
                "version": "1.0",
                "status": "closed",
                "retention_period": "P90D",
                "classification": "security_incident",
                "tags": [
                    "authentication",
                    "security",
                    "token_management"
                ]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="error_log",
            version="1.0",
            description="Schema for representing system error logs and diagnostics",
            schema={
                "type": "object",
                "required": ["timestamp", "error_id", "system_id", "error_context", "error_details"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the error occurrence"
                    },
                    "error_id": {
                        "type": "string",
                        "description": "Unique identifier for the error"
                    },
                    "system_id": {
                        "type": "string",
                        "description": "Identifier of the affected system"
                    },
                    "error_context": {
                        "type": "object",
                        "description": "Context of the error",
                        "required": ["component"],
                        "properties": {
                            "component": {
                                "type": "string",
                                "description": "System component where error occurred"
                            },
                            "environment": {
                                "type": "object",
                                "description": "Environmental context",
                                "properties": {
                                    "environment_type": {
                                        "type": "string",
                                        "enum": ["production", "staging", "development", "testing"],
                                        "description": "Environment type (prod, staging, dev)"
                                    },
                                    "host": {
                                        "type": "string",
                                        "description": "Host identifier"
                                    },
                                    "process_id": {
                                        "type": "string",
                                        "description": "Process identifier"
                                    },
                                    "thread_id": {
                                        "type": "string",
                                        "description": "Thread identifier"
                                    },
                                    "user_id": {
                                        "type": "string",
                                        "description": "User context if applicable"
                                    }
                                }
                            },
                            "session": {
                                "type": "object",
                                "description": "Session information",
                                "properties": {
                                    "session_id": {
                                        "type": "string",
                                        "description": "Session identifier"
                                    },
                                    "start_time": {
                                        "type": "string",
                                        "format": "date-time",
                                        "description": "Session start time"
                                    },
                                    "user_agent": {
                                        "type": "string",
                                        "description": "User agent information"
                                    },
                                    "ip_address": {
                                        "type": "string",
                                        "description": "IP address"
                                    }
                                }
                            }
                        }
                    },
                    "error_details": {
                        "type": "object",
                        "description": "Detailed error information",
                        "required": ["error_type", "severity", "message"],
                        "properties": {
                            "error_type": {
                                "type": "string",
                                "description": "Type of error"
                            },
                            "error_code": {
                                "type": "string",
                                "description": "Error code if available"
                            },
                            "severity": {
                                "type": "string",
                                "enum": ["low", "medium", "high", "critical"],
                                "description": "Error severity level"
                            },
                            "message": {
                                "type": "string",
                                "description": "Error message"
                            },
                            "stack_trace": {
                                "type": "array",
                                "description": "Stack trace",
                                "items": {
                                    "type": "object",
                                    "required": ["file", "line"],
                                    "properties": {
                                        "file": {
                                            "type": "string",
                                            "description": "Source file"
                                        },
                                        "line": {
                                            "type": "integer",
                                            "description": "Line number"
                                        },
                                        "function": {
                                            "type": "string",
                                            "description": "Function name"
                                        },
                                        "code": {
                                            "type": "string",
                                            "description": "Code snippet"
                                        }
                                    }
                                }
                            },
                            "cause": {
                                "type": "object",
                                "description": "Root cause information",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "description": "Cause type"
                                    },
                                    "description": {
                                        "type": "string",
                                        "description": "Cause description"
                                    },
                                    "chain": {
                                        "type": "array",
                                        "description": "Causal chain",
                                        "items": {"type": "string"}
                                    }
                                }
                            }
                        }
                    },
                    "system_state": {
                        "type": "object",
                        "description": "System state at time of error",
                        "properties": {
                            "memory": {
                                "type": "object",
                                "description": "Memory statistics",
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
                                    "heap": {
                                        "type": "object",
                                        "description": "Heap memory details"
                                    }
                                }
                            },
                            "cpu": {
                                "type": "object",
                                "description": "CPU statistics",
                                "properties": {
                                    "usage": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 100,
                                        "description": "CPU usage percentage"
                                    },
                                    "load": {
                                        "type": "array",
                                        "description": "Load averages",
                                        "items": {"type": "number"}
                                    }
                                }
                            },
                            "disk": {
                                "type": "object",
                                "description": "Disk statistics",
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
                                    }
                                }
                            },
                            "network": {
                                "type": "object",
                                "description": "Network statistics",
                                "properties": {
                                    "connections": {
                                        "type": "number",
                                        "description": "Active connections"
                                    },
                                    "throughput": {
                                        "type": "object",
                                        "description": "Network throughput"
                                    }
                                }
                            }
                        }
                    },
                    "related_events": {
                        "type": "array",
                        "description": "Related system events",
                        "items": {
                            "type": "object",
                            "required": ["event_id", "timestamp", "type"],
                            "properties": {
                                "event_id": {
                                    "type": "string",
                                    "description": "Event identifier"
                                },
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "Event timestamp"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Event type"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Event description"
                                },
                                "correlation": {
                                    "type": "string",
                                    "enum": ["direct_cause", "indirect_cause", "symptom", "unrelated"],
                                    "description": "Correlation to error"
                                }
                            }
                        }
                    },
                    "impact_analysis": {
                        "type": "object",
                        "description": "Error impact analysis",
                        "properties": {
                            "affected_services": {
                                "type": "array",
                                "description": "Impacted services",
                                "items": {
                                    "type": "object",
                                    "required": ["service_id", "impact_level"],
                                    "properties": {
                                        "service_id": {
                                            "type": "string",
                                            "description": "Service identifier"
                                        },
                                        "impact_level": {
                                            "type": "string",
                                            "enum": ["low", "medium", "high", "critical"],
                                            "description": "Level of impact"
                                        },
                                        "users_affected": {
                                            "type": "number",
                                            "description": "Number of affected users"
                                        },
                                        "business_impact": {
                                            "type": "string",
                                            "description": "Business impact description"
                                        }
                                    }
                                }
                            },
                            "data_integrity": {
                                "type": "object",
                                "description": "Data integrity impact",
                                "properties": {
                                    "corrupted": {
                                        "type": "boolean",
                                        "description": "Data corruption occurred"
                                    },
                                    "lost": {
                                        "type": "boolean",
                                        "description": "Data loss occurred"
                                    },
                                    "affected_records": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Number of affected records"
                                    }
                                }
                            },
                            "performance_impact": {
                                "type": "object",
                                "description": "Performance impact",
                                "properties": {
                                    "latency_increase": {
                                        "type": "number",
                                        "minimum": 0,
                                        "description": "Increased latency"
                                    },
                                    "throughput_decrease": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 100,
                                        "description": "Decreased throughput"
                                    },
                                    "resource_consumption": {
                                        "type": "object",
                                        "description": "Resource usage impact"
                                    }
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
                                "enum": ["open", "in_progress", "resolved", "closed"],
                                "description": "Resolution status"
                            },
                            "action_taken": {
                                "type": "string",
                                "description": "Action taken to resolve"
                            },
                            "resolution_time": {
                                "type": "string",
                                "format": "duration",
                                "description": "Time to resolve"
                            },
                            "mitigation_steps": {
                                "type": "array",
                                "description": "Steps taken to mitigate",
                                "items": {
                                    "type": "object",
                                    "required": ["step", "timestamp"],
                                    "properties": {
                                        "step": {
                                            "type": "string",
                                            "description": "Mitigation step"
                                        },
                                        "timestamp": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Step timestamp"
                                        },
                                        "outcome": {
                                            "type": "string",
                                            "enum": ["pending", "in_progress", "completed", "failed"],
                                            "description": "Step outcome"
                                        }
                                    }
                                }
                            },
                            "prevention": {
                                "type": "array",
                                "description": "Preventive measures",
                                "items": {
                                    "type": "object",
                                    "required": ["measure"],
                                    "properties": {
                                        "measure": {
                                            "type": "string",
                                            "description": "Preventive measure"
                                        },
                                        "implementation": {
                                            "type": "string",
                                            "description": "Implementation details"
                                        },
                                        "effectiveness": {
                                            "type": "string",
                                            "enum": ["low", "medium", "high"],
                                            "description": "Expected effectiveness"
                                        }
                                    }
                                }
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
                                "description": "Log creator"
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
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "archived"],
                                "description": "Log status"
                            },
                            "retention_period": {
                                "type": "string",
                                "format": "duration",
                                "description": "Log retention period"
                            },
                            "classification": {
                                "type": "string",
                                "description": "Error classification"
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