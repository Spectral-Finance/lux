"""
Schema for managing role assignments in collaborative environments.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class RoleAssignmentSchema(SignalSchema):
    """Schema for managing role assignments in collaborative environments.
    
    This schema defines the structure for documenting and managing role assignments,
    including assignee details, role specifications, responsibilities, and permissions.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "assignment_id": "assign_123",
            "team_id": "team_456",
            "assignee": {
                "user_id": "user_789",
                "name": "Jane Smith",
                "email": "jane.smith@example.com",
                "department": "Engineering",
                "expertise": ["Python", "Machine Learning", "System Design"]
            },
            "role": {
                "role_id": "role_123",
                "title": "Senior Software Engineer",
                "description": "Lead technical implementations and mentor team members",
                "level": "Senior",
                "category": "Engineering"
            },
            "responsibilities": [{
                "responsibility_id": "resp_1",
                "description": "Code review and quality assurance",
                "priority": "high",
                "skills_required": ["Code Review", "Technical Leadership"]
            }],
            "permissions": {
                "access_level": "senior",
                "resources": ["codebase", "production_systems"],
                "actions": ["merge", "deploy", "approve"],
                "restrictions": ["billing_system"]
            },
            "duration": {
                "start_date": "2024-04-01",
                "end_date": "2025-04-01",
                "is_permanent": false,
                "review_frequency": "quarterly"
            },
            "performance_criteria": [{
                "criterion_id": "crit_1",
                "description": "Code quality metrics",
                "metrics": ["code_coverage", "bug_rate"],
                "targets": {
                    "minimum": "80% coverage",
                    "expected": "90% coverage",
                    "exceptional": "95% coverage"
                }
            }],
            "reporting": {
                "reports_to": ["tech_lead_123"],
                "reports_from": ["junior_dev_456", "intern_789"],
                "collaborates_with": ["product_manager_123", "designer_456"]
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "updated_at": "2024-04-03T15:30:00Z",
                "created_by": "hr_manager_123",
                "status": "active",
                "version": "1.0",
                "tags": ["engineering", "senior", "2024"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="role_assignment",
            version="1.0",
            description="Schema for managing and tracking role assignments in collaborative contexts",
            schema={
                "type": "object",
                "required": ["timestamp", "assignment_id", "team_id", "assignee", "role", "responsibilities", "permissions"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the role assignment"
                    },
                    "assignment_id": {
                        "type": "string",
                        "description": "Unique identifier for the role assignment"
                    },
                    "team_id": {
                        "type": "string",
                        "description": "Identifier of the team"
                    },
                    "assignee": {
                        "type": "object",
                        "description": "Information about the person being assigned",
                        "required": ["user_id", "name"],
                        "properties": {
                            "user_id": {
                                "type": "string",
                                "description": "Unique identifier of the assignee"
                            },
                            "name": {
                                "type": "string",
                                "description": "Name of the assignee"
                            },
                            "email": {
                                "type": "string",
                                "format": "email",
                                "description": "Email of the assignee"
                            },
                            "department": {
                                "type": "string",
                                "description": "Department or unit"
                            },
                            "expertise": {
                                "type": "array",
                                "description": "Areas of expertise",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "role": {
                        "type": "object",
                        "description": "Role details",
                        "required": ["role_id", "title", "description"],
                        "properties": {
                            "role_id": {
                                "type": "string",
                                "description": "Unique identifier for the role"
                            },
                            "title": {
                                "type": "string",
                                "description": "Title of the role"
                            },
                            "description": {
                                "type": "string",
                                "description": "Description of role responsibilities"
                            },
                            "level": {
                                "type": "string",
                                "description": "Seniority or level of the role"
                            },
                            "category": {
                                "type": "string",
                                "description": "Category or type of role"
                            }
                        }
                    },
                    "responsibilities": {
                        "type": "array",
                        "description": "Specific responsibilities of the role",
                        "items": {
                            "type": "object",
                            "required": ["responsibility_id", "description"],
                            "properties": {
                                "responsibility_id": {
                                    "type": "string",
                                    "description": "Identifier for the responsibility"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the responsibility"
                                },
                                "priority": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high", "critical"],
                                    "description": "Priority level"
                                },
                                "skills_required": {
                                    "type": "array",
                                    "description": "Required skills",
                                    "items": {
                                        "type": "string"
                                    }
                                }
                            }
                        }
                    },
                    "permissions": {
                        "type": "object",
                        "description": "Access and authority levels",
                        "required": ["access_level"],
                        "properties": {
                            "access_level": {
                                "type": "string",
                                "description": "Overall access level"
                            },
                            "resources": {
                                "type": "array",
                                "description": "Accessible resources",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "actions": {
                                "type": "array",
                                "description": "Permitted actions",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "restrictions": {
                                "type": "array",
                                "description": "Specific restrictions",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "duration": {
                        "type": "object",
                        "description": "Time period of the assignment",
                        "properties": {
                            "start_date": {
                                "type": "string",
                                "format": "date",
                                "description": "Start date of the assignment"
                            },
                            "end_date": {
                                "type": "string",
                                "format": "date",
                                "description": "End date of the assignment"
                            },
                            "is_permanent": {
                                "type": "boolean",
                                "description": "Whether the assignment is permanent"
                            },
                            "review_frequency": {
                                "type": "string",
                                "enum": ["monthly", "quarterly", "semi-annual", "annual"],
                                "description": "How often the assignment is reviewed"
                            }
                        }
                    },
                    "performance_criteria": {
                        "type": "array",
                        "description": "Criteria for evaluating role performance",
                        "items": {
                            "type": "object",
                            "required": ["criterion_id", "description"],
                            "properties": {
                                "criterion_id": {
                                    "type": "string",
                                    "description": "Identifier for the criterion"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the criterion"
                                },
                                "metrics": {
                                    "type": "array",
                                    "description": "Measurement metrics",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "targets": {
                                    "type": "object",
                                    "description": "Performance targets",
                                    "properties": {
                                        "minimum": {
                                            "type": "string",
                                            "description": "Minimum acceptable level"
                                        },
                                        "expected": {
                                            "type": "string",
                                            "description": "Expected performance level"
                                        },
                                        "exceptional": {
                                            "type": "string",
                                            "description": "Exceptional performance level"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "reporting": {
                        "type": "object",
                        "description": "Reporting relationships",
                        "properties": {
                            "reports_to": {
                                "type": "array",
                                "description": "Superior roles",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "reports_from": {
                                "type": "array",
                                "description": "Subordinate roles",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "collaborates_with": {
                                "type": "array",
                                "description": "Peer roles",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the role assignment",
                        "properties": {
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
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the assignment"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "suspended", "completed", "archived"],
                                "description": "Current status of the assignment"
                            },
                            "version": {
                                "type": "string",
                                "description": "Version of the assignment"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    }
                }
            }
        ) 