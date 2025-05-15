"""
Accountability Frame Schema

This schema represents the framework for establishing and maintaining
accountability in systems, processes, and decision-making, including
roles, responsibilities, and oversight mechanisms.
"""

from lux_sdk.signals import SignalSchema

AccountabilityFrameSchema = SignalSchema(
    name="accountability_frame",
    version="1.0",
    description="Schema for defining accountability frameworks",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "frame_id": {
                "type": "string",
                "description": "Unique identifier for this accountability framework"
            },
            "name": {
                "type": "string",
                "description": "Name of the accountability framework"
            },
            "scope": {
                "type": "object",
                "properties": {
                    "system_coverage": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Systems covered by framework"
                    },
                    "organizational_units": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Organizational units involved"
                    },
                    "jurisdiction": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Applicable jurisdictions"
                    }
                },
                "required": ["system_coverage"]
            },
            "roles_responsibilities": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "role": {
                            "type": "string",
                            "description": "Role title or identifier"
                        },
                        "responsibilities": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "List of responsibilities"
                        },
                        "authority_level": {
                            "type": "string",
                            "enum": ["oversight", "decision_making", "implementation", "monitoring", "support"],
                            "description": "Level of authority"
                        },
                        "reporting_to": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Roles this position reports to"
                        }
                    },
                    "required": ["role", "responsibilities", "authority_level"]
                }
            },
            "oversight_mechanisms": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "mechanism_id": {
                            "type": "string",
                            "description": "Identifier for oversight mechanism"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["audit", "review", "monitoring", "reporting", "investigation"],
                            "description": "Type of oversight mechanism"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of mechanism"
                        },
                        "frequency": {
                            "type": "string",
                            "description": "Frequency of oversight activity"
                        },
                        "responsible_parties": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Parties responsible for mechanism"
                        }
                    },
                    "required": ["mechanism_id", "type", "description"]
                }
            },
            "decision_processes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "process_id": {
                            "type": "string",
                            "description": "Identifier for decision process"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of process"
                        },
                        "steps": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "step_id": {
                                        "type": "string",
                                        "description": "Step identifier"
                                    },
                                    "description": {
                                        "type": "string",
                                        "description": "Description of step"
                                    },
                                    "responsible_role": {
                                        "type": "string",
                                        "description": "Role responsible for step"
                                    }
                                },
                                "required": ["step_id", "description"]
                            }
                        }
                    },
                    "required": ["process_id", "name", "steps"]
                }
            },
            "documentation_requirements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "document_type": {
                            "type": "string",
                            "description": "Type of required document"
                        },
                        "purpose": {
                            "type": "string",
                            "description": "Purpose of documentation"
                        },
                        "required_content": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Required content elements"
                        },
                        "retention_period": {
                            "type": "string",
                            "description": "How long to retain document"
                        }
                    },
                    "required": ["document_type", "purpose"]
                }
            },
            "compliance_monitoring": {
                "type": "object",
                "properties": {
                    "metrics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "metric_name": {
                                    "type": "string",
                                    "description": "Name of compliance metric"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of metric"
                                },
                                "measurement_method": {
                                    "type": "string",
                                    "description": "How metric is measured"
                                },
                                "frequency": {
                                    "type": "string",
                                    "description": "Measurement frequency"
                                }
                            },
                            "required": ["metric_name", "description"]
                        }
                    },
                    "reporting_requirements": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "report_type": {
                                    "type": "string",
                                    "description": "Type of report"
                                },
                                "frequency": {
                                    "type": "string",
                                    "description": "Reporting frequency"
                                },
                                "recipients": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Report recipients"
                                }
                            },
                            "required": ["report_type", "frequency"]
                        }
                    }
                }
            },
            "incident_management": {
                "type": "object",
                "properties": {
                    "reporting_procedures": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Procedures for reporting incidents"
                    },
                    "response_protocols": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "incident_type": {
                                    "type": "string",
                                    "description": "Type of incident"
                                },
                                "response_steps": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Steps to respond to incident"
                                }
                            },
                            "required": ["incident_type", "response_steps"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of framework"
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
                        "description": "Version of framework"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "active", "superseded"],
                        "description": "Status of framework"
                    },
                    "review_cycle": {
                        "type": "string",
                        "description": "Framework review frequency"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "frame_id",
            "name",
            "scope",
            "roles_responsibilities",
            "oversight_mechanisms"
        ]
    }
) 