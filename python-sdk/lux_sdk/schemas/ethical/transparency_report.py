"""
Transparency Report Schema

This schema represents the structure for transparency reporting,
including decision-making processes, data usage, and ethical considerations.
"""

from lux_sdk.signals import SignalSchema

TransparencyReportSchema = SignalSchema(
    name="transparency_report",
    version="1.0",
    description="Schema for transparency reporting and ethical disclosure",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "report_id": {
                "type": "string",
                "description": "Unique identifier for this transparency report"
            },
            "project_id": {
                "type": "string",
                "description": "Reference to the associated project"
            },
            "reporting_period": {
                "type": "object",
                "properties": {
                    "start_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Start of reporting period"
                    },
                    "end_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "End of reporting period"
                    }
                },
                "required": ["start_date", "end_date"]
            },
            "system_overview": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the system"
                    },
                    "purpose": {
                        "type": "string",
                        "description": "Purpose of the system"
                    },
                    "scope": {
                        "type": "string",
                        "description": "Scope of system operations"
                    },
                    "stakeholders": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Key stakeholders involved"
                    }
                },
                "required": ["name", "purpose"]
            },
            "decision_making": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "process_id": {
                            "type": "string",
                            "description": "Identifier for decision process"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of decision-making process"
                        },
                        "criteria": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Decision criteria used"
                        },
                        "automation_level": {
                            "type": "string",
                            "enum": ["fully_automated", "partially_automated", "human_in_loop", "human_oversight"],
                            "description": "Level of automation in decision-making"
                        },
                        "human_involvement": {
                            "type": "string",
                            "description": "Description of human role in process"
                        }
                    },
                    "required": ["process_id", "description", "automation_level"]
                }
            },
            "data_practices": {
                "type": "object",
                "properties": {
                    "data_sources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source_id": {
                                    "type": "string",
                                    "description": "Identifier for data source"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of data source"
                                },
                                "data_types": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Types of data collected"
                                }
                            },
                            "required": ["source_id", "description"]
                        }
                    },
                    "data_usage": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "purpose": {
                                    "type": "string",
                                    "description": "Purpose of data usage"
                                },
                                "processing_activities": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Data processing activities"
                                }
                            },
                            "required": ["purpose"]
                        }
                    }
                }
            },
            "ethical_considerations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "category": {
                            "type": "string",
                            "enum": ["fairness", "accountability", "transparency", "privacy", "safety", "other"],
                            "description": "Category of ethical consideration"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of ethical consideration"
                        },
                        "measures_taken": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Measures taken to address consideration"
                        },
                        "challenges": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Challenges encountered"
                        }
                    },
                    "required": ["category", "description"]
                }
            },
            "incidents_issues": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "incident_id": {
                            "type": "string",
                            "description": "Identifier for incident"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["technical", "ethical", "privacy", "security", "other"],
                            "description": "Type of incident"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of incident"
                        },
                        "impact": {
                            "type": "string",
                            "description": "Impact of incident"
                        },
                        "resolution": {
                            "type": "string",
                            "description": "Resolution or mitigation steps"
                        },
                        "date_occurred": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When incident occurred"
                        }
                    },
                    "required": ["incident_id", "type", "description"]
                }
            },
            "improvements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "area": {
                            "type": "string",
                            "description": "Area of improvement"
                        },
                        "planned_actions": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Planned improvement actions"
                        },
                        "timeline": {
                            "type": "string",
                            "description": "Timeline for improvements"
                        }
                    },
                    "required": ["area", "planned_actions"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the report"
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
                        "description": "Version of the report"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "published", "archived"],
                        "description": "Status of the report"
                    },
                    "distribution": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Distribution list for the report"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "report_id",
            "project_id",
            "reporting_period",
            "system_overview",
            "decision_making",
            "ethical_considerations"
        ]
    }
) 