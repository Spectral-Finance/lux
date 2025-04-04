"""
Domain Transfer Schema

This schema represents domain knowledge transfer and adaptation,
including source and target domains, transfer strategies, and validation.
"""

from lux_sdk.signals import SignalSchema

DomainTransferSchema = SignalSchema(
    name="domain_transfer",
    version="1.0",
    description="Schema for domain knowledge transfer and adaptation",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "transfer_id": {
                "type": "string",
                "description": "Unique identifier for this transfer"
            },
            "source_domain": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the source domain"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the source domain"
                    },
                    "key_concepts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "concept_id": {
                                    "type": "string",
                                    "description": "Unique identifier for the concept"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Name of the concept"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the concept"
                                },
                                "relationships": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "related_concept_id": {
                                                "type": "string",
                                                "description": "ID of related concept"
                                            },
                                            "relationship_type": {
                                                "type": "string",
                                                "description": "Type of relationship"
                                            }
                                        }
                                    }
                                }
                            },
                            "required": ["concept_id", "name"]
                        }
                    }
                },
                "required": ["name", "key_concepts"]
            },
            "target_domain": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the target domain"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the target domain"
                    },
                    "existing_knowledge": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "concept_id": {
                                    "type": "string",
                                    "description": "Unique identifier for the concept"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Name of the concept"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the concept"
                                }
                            },
                            "required": ["concept_id", "name"]
                        }
                    },
                    "constraints": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Constraints in the target domain"
                        }
                    }
                },
                "required": ["name"]
            },
            "transfer_strategy": {
                "type": "object",
                "properties": {
                    "approach": {
                        "type": "string",
                        "enum": ["direct", "analogical", "abstraction", "hybrid"],
                        "description": "Type of transfer approach"
                    },
                    "mapping_rules": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source_concept": {
                                    "type": "string",
                                    "description": "Source domain concept"
                                },
                                "target_concept": {
                                    "type": "string",
                                    "description": "Target domain concept"
                                },
                                "transformation": {
                                    "type": "string",
                                    "description": "Transformation rule"
                                },
                                "confidence": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Confidence in mapping"
                                }
                            },
                            "required": ["source_concept", "target_concept"]
                        }
                    },
                    "adaptation_steps": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "step_id": {
                                    "type": "string",
                                    "description": "Unique identifier for the step"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of adaptation step"
                                },
                                "rationale": {
                                    "type": "string",
                                    "description": "Rationale for adaptation"
                                }
                            },
                            "required": ["step_id", "description"]
                        }
                    }
                },
                "required": ["approach", "mapping_rules"]
            },
            "validation": {
                "type": "object",
                "properties": {
                    "methods": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "method_name": {
                                    "type": "string",
                                    "description": "Name of validation method"
                                },
                                "criteria": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Validation criteria"
                                    }
                                },
                                "results": {
                                    "type": "object",
                                    "properties": {
                                        "success": {
                                            "type": "boolean",
                                            "description": "Whether validation passed"
                                        },
                                        "score": {
                                            "type": "number",
                                            "description": "Validation score"
                                        },
                                        "issues": {
                                            "type": "array",
                                            "items": {
                                                "type": "string",
                                                "description": "Identified issues"
                                            }
                                        }
                                    }
                                }
                            },
                            "required": ["method_name", "criteria"]
                        }
                    },
                    "overall_status": {
                        "type": "string",
                        "enum": ["pending", "in_progress", "validated", "failed"],
                        "description": "Overall validation status"
                    }
                },
                "required": ["methods", "overall_status"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the transfer"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the transfer"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Relevant tags"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "transfer_id",
            "source_domain",
            "target_domain",
            "transfer_strategy",
            "validation"
        ]
    }
) 