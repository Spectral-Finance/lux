"""
ExperimentDesignSchema

This schema represents experimental design specifications, including
hypotheses, variables, controls, and measurement protocols.
"""

from lux_sdk.signals import SignalSchema

ExperimentDesignSchema = SignalSchema(
    name="experiment_design",
    version="1.0",
    description="Schema for representing experimental design specifications and protocols",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {"type": "string", "format": "date-time"},
            "experiment_id": {"type": "string"},
            "title": {"type": "string"},
            "description": {"type": "string"},
            "hypotheses": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "statement": {"type": "string"},
                        "rationale": {"type": "string"},
                        "predictions": {"type": "array", "items": {"type": "string"}}
                    },
                    "required": ["id", "statement", "rationale", "predictions"]
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
                                "name": {"type": "string"},
                                "type": {"type": "string"},
                                "levels": {"type": "array", "items": {"type": "string"}},
                                "units": {"type": "string"},
                                "control_value": {"type": "string"}
                            },
                            "required": ["name", "type", "levels", "units"]
                        }
                    },
                    "dependent": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "type": {"type": "string"},
                                "measurement_method": {"type": "string"},
                                "units": {"type": "string"},
                                "expected_range": {
                                    "type": "object",
                                    "properties": {
                                        "min": {"type": "number"},
                                        "max": {"type": "number"}
                                    }
                                }
                            },
                            "required": ["name", "type", "measurement_method", "units"]
                        }
                    },
                    "controlled": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "value": {"type": "string"},
                                "method": {"type": "string"}
                            },
                            "required": ["name", "value", "method"]
                        }
                    }
                },
                "required": ["independent", "dependent"]
            },
            "design": {
                "type": "object",
                "properties": {
                    "type": {"type": "string", "enum": ["factorial", "randomized", "repeated_measures", "mixed"]},
                    "groups": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "size": {"type": "integer", "minimum": 1},
                                "treatment": {"type": "string"}
                            },
                            "required": ["name", "size", "treatment"]
                        }
                    },
                    "randomization": {
                        "type": "object",
                        "properties": {
                            "method": {"type": "string"},
                            "seed": {"type": "integer"}
                        },
                        "required": ["method"]
                    },
                    "blinding": {
                        "type": "object",
                        "properties": {
                            "type": {"type": "string", "enum": ["none", "single", "double", "triple"]},
                            "roles": {"type": "array", "items": {"type": "string"}}
                        }
                    }
                },
                "required": ["type", "groups"]
            },
            "protocols": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "description": {"type": "string"},
                        "steps": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "number": {"type": "integer"},
                                    "action": {"type": "string"},
                                    "duration": {"type": "string"},
                                    "equipment": {"type": "array", "items": {"type": "string"}},
                                    "notes": {"type": "string"}
                                },
                                "required": ["number", "action"]
                            }
                        }
                    },
                    "required": ["name", "description", "steps"]
                }
            },
            "quality_control": {
                "type": "object",
                "properties": {
                    "calibration": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "equipment": {"type": "string"},
                                "frequency": {"type": "string"},
                                "standards": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["equipment", "frequency"]
                        }
                    },
                    "validation": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "method": {"type": "string"},
                                "criteria": {"type": "string"},
                                "frequency": {"type": "string"}
                            },
                            "required": ["method", "criteria", "frequency"]
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {"type": "string"},
                    "creation_date": {"type": "string", "format": "date-time"},
                    "last_modified": {"type": "string", "format": "date-time"},
                    "status": {"type": "string", "enum": ["draft", "active", "completed", "archived"]},
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "funding_source": {"type": "string"},
                    "collaborators": {"type": "array", "items": {"type": "string"}},
                    "ethics_approval": {"type": "string"}
                }
            }
        },
        "required": ["timestamp", "experiment_id", "title", "description", "hypotheses", "variables", "design", "protocols"]
    }
) 