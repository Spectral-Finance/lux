"""
Ethical Principle Schema

This schema represents the definition and application of ethical principles,
including their interpretation, implementation, and evaluation.
"""

from lux_sdk.signals import SignalSchema

EthicalPrincipleSchema = SignalSchema(
    name="ethical_principle",
    version="1.0",
    description="Schema for defining and applying ethical principles",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "principle_id": {
                "type": "string",
                "description": "Unique identifier for this ethical principle"
            },
            "name": {
                "type": "string",
                "description": "Name of the ethical principle"
            },
            "category": {
                "type": "string",
                "enum": [
                    "autonomy",
                    "beneficence",
                    "non_maleficence",
                    "justice",
                    "privacy",
                    "transparency",
                    "accountability",
                    "sustainability",
                    "dignity",
                    "other"
                ],
                "description": "Category of ethical principle"
            },
            "description": {
                "type": "string",
                "description": "Detailed description of the principle"
            },
            "rationale": {
                "type": "string",
                "description": "Reasoning behind the principle"
            },
            "scope": {
                "type": "object",
                "properties": {
                    "domains": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Domains where principle applies"
                    },
                    "limitations": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Limitations or exceptions to principle"
                    }
                }
            },
            "implementation": {
                "type": "object",
                "properties": {
                    "guidelines": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "guideline_id": {
                                    "type": "string",
                                    "description": "Identifier for this guideline"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the guideline"
                                },
                                "examples": {
                                    "type": "array",
                                    "items": {
                                        "type": "string"
                                    },
                                    "description": "Examples of guideline application"
                                }
                            },
                            "required": ["guideline_id", "description"]
                        }
                    },
                    "requirements": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "requirement_id": {
                                    "type": "string",
                                    "description": "Identifier for this requirement"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the requirement"
                                },
                                "verification_method": {
                                    "type": "string",
                                    "description": "How to verify requirement is met"
                                }
                            },
                            "required": ["requirement_id", "description"]
                        }
                    }
                }
            },
            "evaluation_criteria": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "criterion_id": {
                            "type": "string",
                            "description": "Identifier for this criterion"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the criterion"
                        },
                        "metrics": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "metric_name": {
                                        "type": "string",
                                        "description": "Name of the metric"
                                    },
                                    "measurement_method": {
                                        "type": "string",
                                        "description": "How to measure this metric"
                                    },
                                    "target_value": {
                                        "type": "string",
                                        "description": "Target value or range"
                                    }
                                },
                                "required": ["metric_name", "measurement_method"]
                            }
                        }
                    },
                    "required": ["criterion_id", "description"]
                }
            },
            "conflicts_resolution": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "conflict_type": {
                            "type": "string",
                            "description": "Type of potential conflict"
                        },
                        "resolution_approach": {
                            "type": "string",
                            "description": "Approach to resolving conflict"
                        },
                        "priority_rules": {
                            "type": "array",
                            "items": {
                                "type": "string"
                            },
                            "description": "Rules for prioritizing principles"
                        }
                    },
                    "required": ["conflict_type", "resolution_approach"]
                }
            },
            "references": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "source": {
                            "type": "string",
                            "description": "Source of reference"
                        },
                        "relevance": {
                            "type": "string",
                            "description": "Relevance to principle"
                        }
                    },
                    "required": ["source"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the principle"
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
                        "description": "Version of the principle"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "archived"],
                        "description": "Status of the principle"
                    },
                    "review_cycle": {
                        "type": "string",
                        "description": "Frequency of principle review"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "principle_id",
            "name",
            "category",
            "description",
            "rationale"
        ]
    }
) 