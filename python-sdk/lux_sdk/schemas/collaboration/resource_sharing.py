"""
Resource Sharing Schema

This schema represents the sharing of resources between collaborating entities,
including access permissions, usage tracking, and sharing policies.
"""

from lux_sdk.signals import SignalSchema

ResourceSharingSchema = SignalSchema(
    name="resource_sharing",
    version="1.0",
    description="Schema for managing and tracking shared resources and their access patterns",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "sharing_id": {
                "type": "string",
                "description": "Unique identifier for this sharing arrangement"
            },
            "resource": {
                "type": "object",
                "properties": {
                    "resource_id": {
                        "type": "string",
                        "description": "Identifier of the shared resource"
                    },
                    "type": {
                        "type": "string",
                        "enum": ["data", "compute", "storage", "model", "api"],
                        "description": "Type of resource being shared"
                    },
                    "name": {
                        "type": "string",
                        "description": "Name of the resource"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the resource"
                    }
                },
                "required": ["resource_id", "type", "name"]
            },
            "owner": {
                "type": "object",
                "properties": {
                    "owner_id": {
                        "type": "string",
                        "description": "ID of the resource owner"
                    },
                    "owner_type": {
                        "type": "string",
                        "enum": ["user", "team", "organization", "system"],
                        "description": "Type of owner entity"
                    }
                },
                "required": ["owner_id", "owner_type"]
            },
            "recipients": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "recipient_id": {
                            "type": "string",
                            "description": "ID of the recipient"
                        },
                        "recipient_type": {
                            "type": "string",
                            "enum": ["user", "team", "organization", "system"],
                            "description": "Type of recipient entity"
                        },
                        "access_level": {
                            "type": "string",
                            "enum": ["read", "write", "admin"],
                            "description": "Level of access granted"
                        }
                    },
                    "required": ["recipient_id", "recipient_type", "access_level"]
                }
            },
            "sharing_policy": {
                "type": "object",
                "properties": {
                    "duration": {
                        "type": "object",
                        "properties": {
                            "start_time": {
                                "type": "string",
                                "format": "date-time"
                            },
                            "end_time": {
                                "type": "string",
                                "format": "date-time"
                            }
                        }
                    },
                    "usage_limits": {
                        "type": "object",
                        "properties": {
                            "max_concurrent_users": {
                                "type": "integer",
                                "minimum": 1
                            },
                            "max_usage_time": {
                                "type": "integer",
                                "description": "Maximum usage time in seconds"
                            },
                            "max_requests": {
                                "type": "integer",
                                "minimum": 1
                            }
                        }
                    },
                    "revocation_policy": {
                        "type": "object",
                        "properties": {
                            "auto_revoke_conditions": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "enum": ["time_expired", "usage_limit_reached", "policy_violation"]
                                }
                            },
                            "revocation_notice_period": {
                                "type": "integer",
                                "description": "Notice period in seconds before revocation"
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_at": {
                        "type": "string",
                        "format": "date-time"
                    },
                    "last_modified": {
                        "type": "string",
                        "format": "date-time"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    },
                    "notes": {
                        "type": "string"
                    }
                }
            }
        },
        "required": ["timestamp", "sharing_id", "resource", "owner", "recipients"]
    }
) 