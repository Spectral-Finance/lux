"""
Schema for task execution plans.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ExecutionPlanSchema(SignalSchema):
    """Schema for representing task execution plans.
    
    This schema defines the structure for representing detailed execution plans for tasks,
    including phases, steps, resources, timelines, dependencies, and risk management.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "plan_id": "plan_20240403_153000",
            "task_id": "task_789",
            "overview": {
                "title": "Data Migration Plan",
                "description": "Plan for migrating user data to new database",
                "objectives": ["Minimize downtime", "Ensure data integrity"],
                "success_criteria": ["Zero data loss", "< 2 hours downtime"]
            },
            "phases": [{
                "phase_id": "phase_1",
                "name": "Preparation",
                "description": "Setup and validation of migration tools",
                "status": "completed",
                "dependencies": ["resource_allocation"]
            }],
            "steps": [{
                "step_id": "step_1",
                "phase_id": "phase_1",
                "name": "Database Backup",
                "description": "Create full backup of source database",
                "status": "pending",
                "estimated_duration": "30m",
                "assigned_to": ["db_admin"],
                "validation_criteria": ["Backup size matches source", "Checksum verified"]
            }],
            "resources": [{
                "resource_id": "res_1",
                "type": "human",
                "name": "Database Administrator",
                "quantity": 1,
                "skills_required": ["PostgreSQL", "Data Migration"],
                "availability": {
                    "start_time": "2024-04-03T15:00:00Z",
                    "end_time": "2024-04-03T18:00:00Z"
                }
            }],
            "timeline": {
                "start_time": "2024-04-03T15:00:00Z",
                "end_time": "2024-04-03T17:00:00Z",
                "milestones": [{
                    "milestone_id": "m1",
                    "name": "Backup Complete",
                    "target_time": "2024-04-03T15:30:00Z",
                    "dependencies": ["step_1"]
                }],
                "critical_path": ["step_1", "step_2", "step_3"]
            },
            "dependencies": [{
                "dependency_id": "dep_1",
                "type": "external_service",
                "name": "Cloud Storage Service",
                "status": "available",
                "requirements": {
                    "storage_space": "500GB",
                    "access_level": "write"
                }
            }],
            "risks": [{
                "risk_id": "risk_1",
                "description": "Network connectivity issues",
                "probability": "medium",
                "impact": "high",
                "mitigation_strategy": "Redundant network connections",
                "contingency_plan": "Switch to backup network"
            }],
            "metadata": {
                "created_at": "2024-04-03T14:00:00Z",
                "created_by": "planner_123",
                "last_updated": "2024-04-03T14:30:00Z",
                "version": "1.0",
                "status": "draft",
                "priority": "high",
                "tags": ["data_migration", "planned_maintenance"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="execution_plan",
            version="1.0",
            description="Schema for representing task execution plans",
            schema={
                "type": "object",
                "required": ["timestamp", "plan_id", "task_id", "overview", "phases", "steps", "resources"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the execution plan"
                    },
                    "plan_id": {
                        "type": "string",
                        "description": "Unique identifier for the execution plan"
                    },
                    "task_id": {
                        "type": "string",
                        "description": "Reference to the associated task"
                    },
                    "overview": {
                        "type": "object",
                        "required": ["title", "description", "objectives"],
                        "description": "High-level plan overview",
                        "properties": {
                            "title": {
                                "type": "string",
                                "description": "Plan title"
                            },
                            "description": {
                                "type": "string",
                                "description": "Plan description"
                            },
                            "objectives": {
                                "type": "array",
                                "description": "Plan objectives",
                                "items": {"type": "string"}
                            },
                            "success_criteria": {
                                "type": "array",
                                "description": "Success criteria",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "phases": {
                        "type": "array",
                        "description": "Execution phases",
                        "items": {
                            "type": "object",
                            "required": ["phase_id", "name", "description", "status"],
                            "properties": {
                                "phase_id": {
                                    "type": "string",
                                    "description": "Phase identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Phase name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Phase description"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["not_started", "in_progress", "completed", "blocked"],
                                    "description": "Phase status"
                                },
                                "dependencies": {
                                    "type": "array",
                                    "description": "Phase dependencies",
                                    "items": {"type": "string"}
                                }
                            }
                        }
                    },
                    "steps": {
                        "type": "array",
                        "description": "Detailed execution steps",
                        "items": {
                            "type": "object",
                            "required": ["step_id", "phase_id", "name", "description", "status"],
                            "properties": {
                                "step_id": {
                                    "type": "string",
                                    "description": "Step identifier"
                                },
                                "phase_id": {
                                    "type": "string",
                                    "description": "Reference to parent phase"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Step name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Step description"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["pending", "in_progress", "completed", "failed"],
                                    "description": "Step status"
                                },
                                "estimated_duration": {
                                    "type": "string",
                                    "description": "Estimated duration"
                                },
                                "assigned_to": {
                                    "type": "array",
                                    "description": "Assigned resources",
                                    "items": {"type": "string"}
                                },
                                "validation_criteria": {
                                    "type": "array",
                                    "description": "Success validation criteria",
                                    "items": {"type": "string"}
                                }
                            }
                        }
                    },
                    "resources": {
                        "type": "array",
                        "description": "Required resources",
                        "items": {
                            "type": "object",
                            "required": ["resource_id", "type", "name"],
                            "properties": {
                                "resource_id": {
                                    "type": "string",
                                    "description": "Resource identifier"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["human", "computational", "physical", "financial"],
                                    "description": "Resource type"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Resource name"
                                },
                                "quantity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "description": "Required quantity"
                                },
                                "skills_required": {
                                    "type": "array",
                                    "description": "Required skills (for human resources)",
                                    "items": {"type": "string"}
                                },
                                "availability": {
                                    "type": "object",
                                    "description": "Resource availability window",
                                    "properties": {
                                        "start_time": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Start of availability"
                                        },
                                        "end_time": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "End of availability"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "timeline": {
                        "type": "object",
                        "description": "Execution timeline",
                        "properties": {
                            "start_time": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Plan start time"
                            },
                            "end_time": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Plan end time"
                            },
                            "milestones": {
                                "type": "array",
                                "description": "Key milestones",
                                "items": {
                                    "type": "object",
                                    "required": ["milestone_id", "name", "target_time"],
                                    "properties": {
                                        "milestone_id": {
                                            "type": "string",
                                            "description": "Milestone identifier"
                                        },
                                        "name": {
                                            "type": "string",
                                            "description": "Milestone name"
                                        },
                                        "target_time": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Target completion time"
                                        },
                                        "dependencies": {
                                            "type": "array",
                                            "description": "Milestone dependencies",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            },
                            "critical_path": {
                                "type": "array",
                                "description": "Critical path steps",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "dependencies": {
                        "type": "array",
                        "description": "External dependencies",
                        "items": {
                            "type": "object",
                            "required": ["dependency_id", "type", "name", "status"],
                            "properties": {
                                "dependency_id": {
                                    "type": "string",
                                    "description": "Dependency identifier"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["external_service", "system", "data", "approval"],
                                    "description": "Dependency type"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Dependency name"
                                },
                                "status": {
                                    "type": "string",
                                    "enum": ["available", "unavailable", "pending"],
                                    "description": "Dependency status"
                                },
                                "requirements": {
                                    "type": "object",
                                    "description": "Dependency requirements"
                                }
                            }
                        }
                    },
                    "risks": {
                        "type": "array",
                        "description": "Identified risks and mitigation",
                        "items": {
                            "type": "object",
                            "required": ["risk_id", "description", "probability", "impact"],
                            "properties": {
                                "risk_id": {
                                    "type": "string",
                                    "description": "Risk identifier"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Risk description"
                                },
                                "probability": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high"],
                                    "description": "Risk probability"
                                },
                                "impact": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high"],
                                    "description": "Risk impact"
                                },
                                "mitigation_strategy": {
                                    "type": "string",
                                    "description": "Risk mitigation strategy"
                                },
                                "contingency_plan": {
                                    "type": "string",
                                    "description": "Risk contingency plan"
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the execution plan",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Plan creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Plan version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "review", "approved", "in_progress", "completed"],
                                "description": "Plan status"
                            },
                            "priority": {
                                "type": "string",
                                "enum": ["low", "medium", "high", "critical"],
                                "description": "Plan priority"
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