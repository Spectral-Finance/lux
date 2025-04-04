"""
Error Handling Schema

This schema represents error handling strategies and protocols for task execution,
including error detection, recovery procedures, and fallback mechanisms.
"""

from lux_sdk.signals import SignalSchema

ErrorHandlingSchema = SignalSchema(
    name="error_handling",
    version="1.0",
    description="Schema for task error handling and recovery",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "error_id": {
                "type": "string",
                "description": "Unique identifier for this error handling instance"
            },
            "task_id": {
                "type": "string",
                "description": "Reference to the task where error occurred"
            },
            "error_type": {
                "type": "string",
                "enum": ["validation", "execution", "resource", "dependency", "timeout", "system", "other"],
                "description": "Category of error encountered"
            },
            "severity": {
                "type": "string",
                "enum": ["critical", "high", "medium", "low"],
                "description": "Severity level of the error"
            },
            "error_details": {
                "type": "object",
                "properties": {
                    "message": {
                        "type": "string",
                        "description": "Detailed error message"
                    },
                    "stack_trace": {
                        "type": "string",
                        "description": "Stack trace if available"
                    },
                    "context": {
                        "type": "object",
                        "description": "Additional context about the error"
                    }
                },
                "required": ["message"]
            },
            "recovery_strategy": {
                "type": "object",
                "properties": {
                    "strategy_type": {
                        "type": "string",
                        "enum": ["retry", "fallback", "compensate", "abort", "manual_intervention"],
                        "description": "Type of recovery strategy"
                    },
                    "max_retries": {
                        "type": "integer",
                        "minimum": 0,
                        "description": "Maximum number of retry attempts"
                    },
                    "retry_interval": {
                        "type": "integer",
                        "minimum": 0,
                        "description": "Interval between retries in seconds"
                    },
                    "fallback_procedure": {
                        "type": "string",
                        "description": "Description of fallback procedure"
                    }
                },
                "required": ["strategy_type"]
            },
            "status": {
                "type": "string",
                "enum": ["detected", "handling", "resolved", "failed"],
                "description": "Current status of error handling"
            },
            "resolution": {
                "type": "object",
                "properties": {
                    "successful": {
                        "type": "boolean",
                        "description": "Whether error was successfully resolved"
                    },
                    "resolution_time": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the error was resolved"
                    },
                    "resolution_details": {
                        "type": "string",
                        "description": "Details about how error was resolved"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the error handling record"
                    },
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
                    "version": {
                        "type": "string",
                        "description": "Version of the error handling record"
                    }
                }
            }
        },
        "required": ["timestamp", "error_id", "task_id", "error_type", "severity", "error_details", "status"]
    }
) 