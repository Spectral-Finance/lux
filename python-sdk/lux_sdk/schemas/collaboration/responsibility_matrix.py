"""
Responsibility Matrix Schema

This schema represents the allocation and tracking of responsibilities in collaborative work,
including role assignments, task ownership, and accountability frameworks.
"""

from lux_sdk.signals import SignalSchema

ResponsibilityMatrixSchema = SignalSchema(
    name="responsibility_matrix",
    version="1.0",
    description="Schema for responsibility allocation and tracking",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "matrix_id": {
                "type": "string",
                "description": "Unique identifier for this responsibility matrix"
            },
            "project_id": {
                "type": "string",
                "description": "Reference to the associated project"
            },
            "title": {
                "type": "string",
                "description": "Title of the responsibility matrix"
            },
            "description": {
                "type": "string",
                "description": "Description of the matrix's purpose and scope"
            },
            "stakeholders": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "stakeholder_id": {
                            "type": "string",
                            "description": "Unique identifier for the stakeholder"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the stakeholder"
                        },
                        "role": {
                            "type": "string",
                            "description": "Role in the project"
                        },
                        "department": {
                            "type": "string",
                            "description": "Department or organizational unit"
                        }
                    },
                    "required": ["stakeholder_id", "name", "role"]
                }
            },
            "activities": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "activity_id": {
                            "type": "string",
                            "description": "Unique identifier for the activity"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the activity"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the activity"
                        },
                        "assignments": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "stakeholder_id": {
                                        "type": "string",
                                        "description": "Reference to stakeholder"
                                    },
                                    "responsibility_type": {
                                        "type": "string",
                                        "enum": ["responsible", "accountable", "consulted", "informed"],
                                        "description": "RACI matrix responsibility type"
                                    },
                                    "notes": {
                                        "type": "string",
                                        "description": "Additional notes about the assignment"
                                    }
                                },
                                "required": ["stakeholder_id", "responsibility_type"]
                            }
                        }
                    },
                    "required": ["activity_id", "name", "assignments"]
                }
            },
            "dependencies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "activity_id": {
                            "type": "string",
                            "description": "Activity with dependency"
                        },
                        "depends_on": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "IDs of activities this depends on"
                            }
                        }
                    },
                    "required": ["activity_id", "depends_on"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the matrix"
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
                        "description": "Version of the matrix"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "active", "archived"],
                        "description": "Current status of the matrix"
                    }
                }
            }
        },
        "required": ["timestamp", "matrix_id", "project_id", "title", "stakeholders", "activities"]
    }
) 