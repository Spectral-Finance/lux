"""
Configuration Update Schema

This schema defines the structure for tracking system configuration changes,
including what was changed, who made the change, and the impact of the change.
"""

from lux_sdk.signals import SignalSchema

ConfigurationUpdateSchema = SignalSchema(
    name="configuration_update",
    version="1.0",
    description="Schema for tracking system configuration changes",
    schema={
        "type": "object",
        "description": "Schema for system configuration updates",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "When the configuration update was made"
            },
            "update_id": {
                "type": "string",
                "description": "Unique identifier for this configuration update"
            },
            "system_id": {
                "type": "string",
                "description": "Identifier of the system being configured"
            },
            "component": {
                "type": "object",
                "description": "The system component being modified",
                "properties": {
                    "name": {"type": "string"},
                    "type": {
                        "type": "string",
                        "enum": [
                            "hardware",
                            "software",
                            "network",
                            "security",
                            "database",
                            "application",
                            "operating_system",
                            "middleware",
                            "service"
                        ]
                    },
                    "version": {"type": "string"},
                    "path": {"type": "string"}
                },
                "required": ["name", "type"]
            },
            "changes": {
                "type": "array",
                "description": "List of configuration changes made",
                "items": {
                    "type": "object",
                    "properties": {
                        "parameter": {"type": "string"},
                        "previous_value": {"type": "string"},
                        "new_value": {"type": "string"},
                        "change_type": {
                            "type": "string",
                            "enum": ["add", "modify", "delete", "reset"]
                        }
                    },
                    "required": ["parameter", "change_type"]
                }
            },
            "reason": {
                "type": "object",
                "description": "Reason for the configuration change",
                "properties": {
                    "category": {
                        "type": "string",
                        "enum": [
                            "performance_optimization",
                            "security_patch",
                            "bug_fix",
                            "feature_enhancement",
                            "compliance_requirement",
                            "maintenance",
                            "emergency_fix"
                        ]
                    },
                    "description": {"type": "string"},
                    "ticket_id": {"type": "string"},
                    "priority": {
                        "type": "string",
                        "enum": ["critical", "high", "medium", "low"]
                    }
                },
                "required": ["category", "description"]
            },
            "validation": {
                "type": "object",
                "description": "Validation of the configuration change",
                "properties": {
                    "tested": {"type": "boolean"},
                    "test_results": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "test_name": {"type": "string"},
                                "status": {
                                    "type": "string",
                                    "enum": ["passed", "failed", "skipped"]
                                },
                                "details": {"type": "string"}
                            },
                            "required": ["test_name", "status"]
                        }
                    },
                    "validation_environment": {"type": "string"},
                    "validator": {"type": "string"}
                },
                "required": ["tested"]
            },
            "impact": {
                "type": "object",
                "description": "Impact assessment of the configuration change",
                "properties": {
                    "affected_systems": {
                        "type": "array",
                        "items": {"type": "string"}
                    },
                    "downtime_required": {"type": "boolean"},
                    "estimated_downtime": {"type": "string"},
                    "risk_level": {
                        "type": "string",
                        "enum": ["none", "low", "medium", "high", "critical"]
                    },
                    "rollback_plan": {"type": "string"}
                },
                "required": ["affected_systems", "downtime_required"]
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the configuration update",
                "properties": {
                    "author": {"type": "string"},
                    "approved_by": {"type": "string"},
                    "approval_date": {"type": "string", "format": "date-time"},
                    "environment": {
                        "type": "string",
                        "enum": ["development", "testing", "staging", "production"]
                    },
                    "backup_created": {"type": "boolean"},
                    "backup_location": {"type": "string"},
                    "documentation_updated": {"type": "boolean"},
                    "documentation_link": {"type": "string"},
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"}
                    }
                },
                "required": ["author", "environment"]
            }
        },
        "required": [
            "timestamp",
            "update_id",
            "system_id",
            "component",
            "changes",
            "reason",
            "impact",
            "metadata"
        ]
    }) 