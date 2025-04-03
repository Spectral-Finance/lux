"""
Experiment Design Schema

This schema represents scientific experiment designs, including hypotheses,
methodology, variables, and controls.
"""

from lux_sdk.signals import SignalSchema

ExperimentDesignSchema = SignalSchema(
    name="experiment_design",
    version="1.0",
    description="Schema for defining scientific experiment designs and methodologies",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "experiment_id": {
                "type": "string",
                "description": "Unique identifier for this experiment"
            },
            "title": {
                "type": "string",
                "description": "Title of the experiment"
            },
            "research_question": {
                "type": "string",
                "description": "Primary research question being investigated"
            },
            "hypotheses": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "hypothesis_id": {
                            "type": "string",
                            "description": "Identifier for the hypothesis"
                        },
                        "statement": {
                            "type": "string",
                            "description": "Formal hypothesis statement"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["null", "alternative", "directional"],
                            "description": "Type of hypothesis"
                        },
                        "rationale": {
                            "type": "string",
                            "description": "Reasoning behind the hypothesis"
                        }
                    },
                    "required": ["hypothesis_id", "statement", "type"]
                }
            },
            "variables": {
                "type": "object",
                "properties": {
                    "independent": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Variable name"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["categorical", "continuous", "discrete"],
                                    "description": "Variable type"
                                },
                                "levels": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Possible values or levels"
                                    }
                                },
                                "units": {
                                    "type": "string",
                                    "description": "Units of measurement"
                                }
                            },
                            "required": ["name", "type"]
                        }
                    },
                    "dependent": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Variable name"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["categorical", "continuous", "discrete"],
                                    "description": "Variable type"
                                },
                                "measurement_method": {
                                    "type": "string",
                                    "description": "How the variable is measured"
                                },
                                "units": {
                                    "type": "string",
                                    "description": "Units of measurement"
                                }
                            },
                            "required": ["name", "type", "measurement_method"]
                        }
                    },
                    "control": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Variable name"
                                },
                                "control_method": {
                                    "type": "string",
                                    "description": "How the variable is controlled"
                                }
                            },
                            "required": ["name", "control_method"]
                        }
                    }
                },
                "required": ["independent", "dependent"]
            },
            "methodology": {
                "type": "object",
                "properties": {
                    "design_type": {
                        "type": "string",
                        "enum": ["between_subjects", "within_subjects", "mixed", "factorial", "time_series"],
                        "description": "Type of experimental design"
                    },
                    "sampling": {
                        "type": "object",
                        "properties": {
                            "method": {
                                "type": "string",
                                "description": "Sampling method used"
                            },
                            "size": {
                                "type": "integer",
                                "description": "Sample size"
                            },
                            "power_analysis": {
                                "type": "object",
                                "description": "Statistical power analysis details"
                            }
                        },
                        "required": ["method", "size"]
                    },
                    "randomization": {
                        "type": "object",
                        "properties": {
                            "method": {
                                "type": "string",
                                "description": "Randomization method"
                            },
                            "seed": {
                                "type": "integer",
                                "description": "Random seed for reproducibility"
                            }
                        }
                    },
                    "blinding": {
                        "type": "object",
                        "properties": {
                            "type": {
                                "type": "string",
                                "enum": ["none", "single", "double", "triple"],
                                "description": "Type of blinding"
                            },
                            "roles": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "Roles that are blinded"
                                }
                            }
                        }
                    }
                },
                "required": ["design_type", "sampling"]
            },
            "procedures": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "step_id": {
                            "type": "string",
                            "description": "Identifier for the procedure step"
                        },
                        "description": {
                            "type": "string",
                            "description": "Detailed description of the step"
                        },
                        "duration": {
                            "type": "string",
                            "description": "Expected duration of the step"
                        },
                        "materials": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Required materials"
                            }
                        }
                    },
                    "required": ["step_id", "description"]
                }
            },
            "analysis_plan": {
                "type": "object",
                "properties": {
                    "statistical_tests": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "test_name": {
                                    "type": "string",
                                    "description": "Name of statistical test"
                                },
                                "variables": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Variables involved"
                                    }
                                },
                                "assumptions": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Test assumptions"
                                    }
                                }
                            },
                            "required": ["test_name", "variables"]
                        }
                    },
                    "significance_level": {
                        "type": "number",
                        "description": "Alpha level for significance testing"
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "researchers": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "id": {
                                    "type": "string",
                                    "description": "Researcher identifier"
                                },
                                "role": {
                                    "type": "string",
                                    "description": "Role in the experiment"
                                }
                            },
                            "required": ["id", "role"]
                        }
                    },
                    "institution": {
                        "type": "string",
                        "description": "Research institution"
                    },
                    "funding": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source": {
                                    "type": "string",
                                    "description": "Funding source"
                                },
                                "grant_id": {
                                    "type": "string",
                                    "description": "Grant identifier"
                                }
                            }
                        }
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "experiment_id", "title", "research_question", "hypotheses", "variables", "methodology"]
    }
) 