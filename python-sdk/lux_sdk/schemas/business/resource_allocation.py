"""
Resource Allocation Schema

This schema defines the structure for resource allocation in business contexts,
including human resources, financial resources, and material resources.
"""

from lux_sdk.signals import SignalSchema

ResourceAllocationSchema = SignalSchema(
    name="resource_allocation",
    version="1.0",
    description="Schema for tracking resource allocation in business contexts",
    schema={
        "type": "object",
        "description": "Schema for resource allocation tracking",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the allocation was recorded"
            },
            "allocation_id": {
                "type": "string",
                "description": "Unique identifier for this resource allocation"
            },
            "project_id": {
                "type": "string",
                "description": "Reference to the project requiring resources"
            },
            "resources": {
                "type": "array",
                "description": "List of allocated resources",
                "items": {
                    "type": "object",
                    "properties": {
                        "resource_id": {"type": "string"},
                        "type": {
                            "type": "string",
                            "enum": ["human", "financial", "material", "technological", "facility"]
                        },
                        "name": {"type": "string"},
                        "quantity": {
                            "type": "object",
                            "properties": {
                                "value": {"type": "number"},
                                "unit": {"type": "string"}
                            },
                            "required": ["value", "unit"]
                        },
                        "cost": {
                            "type": "object",
                            "properties": {
                                "amount": {"type": "number"},
                                "currency": {"type": "string"}
                            },
                            "required": ["amount", "currency"]
                        },
                        "availability": {
                            "type": "object",
                            "properties": {
                                "start_date": {"type": "string", "format": "date"},
                                "end_date": {"type": "string", "format": "date"},
                                "utilization_percentage": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 100
                                }
                            },
                            "required": ["start_date", "end_date"]
                        }
                    },
                    "required": ["resource_id", "type", "name", "quantity"]
                }
            },
            "allocation_strategy": {
                "type": "object",
                "description": "Strategy for resource allocation",
                "properties": {
                    "priority_level": {
                        "type": "string",
                        "enum": ["critical", "high", "medium", "low"]
                    },
                    "allocation_method": {
                        "type": "string",
                        "enum": ["fixed", "dynamic", "on_demand", "shared"]
                    },
                    "constraints": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {"type": "string"},
                                "description": {"type": "string"},
                                "threshold": {"type": "number"}
                            },
                            "required": ["type", "description"]
                        }
                    }
                },
                "required": ["priority_level", "allocation_method"]
            },
            "dependencies": {
                "type": "array",
                "description": "Dependencies between allocated resources",
                "items": {
                    "type": "object",
                    "properties": {
                        "resource_id": {"type": "string"},
                        "depends_on": {
                            "type": "array",
                            "items": {"type": "string"}
                        },
                        "dependency_type": {
                            "type": "string",
                            "enum": ["required", "optional", "exclusive"]
                        }
                    },
                    "required": ["resource_id", "depends_on", "dependency_type"]
                }
            },
            "optimization_goals": {
                "type": "array",
                "description": "Goals for optimizing resource allocation",
                "items": {
                    "type": "object",
                    "properties": {
                        "goal_type": {
                            "type": "string",
                            "enum": ["cost_reduction", "efficiency", "utilization", "performance"]
                        },
                        "target_value": {"type": "number"},
                        "current_value": {"type": "number"},
                        "weight": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1
                        }
                    },
                    "required": ["goal_type", "target_value", "weight"]
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the resource allocation",
                "properties": {
                    "allocator": {"type": "string"},
                    "allocation_date": {"type": "string", "format": "date"},
                    "last_reviewed": {"type": "string", "format": "date-time"},
                    "review_cycle": {
                        "type": "string",
                        "enum": ["daily", "weekly", "monthly", "quarterly"]
                    },
                    "status": {
                        "type": "string",
                        "enum": ["planned", "active", "completed", "cancelled"]
                    }
                },
                "required": ["allocator", "allocation_date", "status"]
            }
        },
        "required": [
            "timestamp",
            "allocation_id",
            "project_id",
            "resources",
            "allocation_strategy",
            "metadata"
        ]
    }) 