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
            "timestamp": {"type": "string", "format": "date-time", "required": True},
            "experiment_id": {"type": "string", "required": True},
            "title": {"type": "string", "required": True},
            "description": {"type": "string", "required": True},
            "hypotheses": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string", "required": True},
                        "statement": {"type": "string", "required": True},
                        "rationale": {"type": "string", "required": True},
                        "predictions": {"type": "array", "items": {"type": "string"}, "required": True}
                    }
                }
            },
            "variables": {
                "type": "object",
                "required": True,
                "properties": {
                    "independent": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "type": {"type": "string", "required": True},
                                "levels": {"type": "array", "items": {"type": "string"}, "required": True},
                                "units": {"type": "string", "required": True},
                                "control_value": {"type": "string"}
                            }
                        }
                    },
                    "dependent": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "type": {"type": "string", "required": True},
                                "measurement_method": {"type": "string", "required": True},
                                "units": {"type": "string", "required": True},
                                "expected_range": {
                                    "type": "object",
                                    "properties": {
                                        "min": {"type": "number"},
                                        "max": {"type": "number"}
                                    }
                                }
                            }
                        }
                    },
                    "controlled": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "value": {"type": "string", "required": True},
                                "method": {"type": "string", "required": True}
                            }
                        }
                    }
                }
            },
            "design": {
                "type": "object",
                "required": True,
                "properties": {
                    "type": {"type": "string", "enum": ["factorial", "randomized", "repeated_measures", "mixed"], "required": True},
                    "groups": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "required": True},
                                "size": {"type": "integer", "minimum": 1, "required": True},
                                "treatment": {"type": "string", "required": True}
                            }
                        }
                    },
                    "randomization": {
                        "type": "object",
                        "properties": {
                            "method": {"type": "string", "required": True},
                            "seed": {"type": "integer"}
                        }
                    },
                    "blinding": {
                        "type": "object",
                        "properties": {
                            "type": {"type": "string", "enum": ["none", "single", "double", "triple"]},
                            "roles": {"type": "array", "items": {"type": "string"}}
                        }
                    }
                }
            },
            "protocols": {
                "type": "array",
                "required": True,
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string", "required": True},
                        "description": {"type": "string", "required": True},
                        "steps": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "number": {"type": "integer", "required": True},
                                    "action": {"type": "string", "required": True},
                                    "duration": {"type": "string"},
                                    "equipment": {"type": "array", "items": {"type": "string"}},
                                    "notes": {"type": "string"}
                                }
                            }
                        }
                    }
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
                                "equipment": {"type": "string", "required": True},
                                "frequency": {"type": "string", "required": True},
                                "standards": {"type": "array", "items": {"type": "string"}}
                            }
                        }
                    },
                    "validation": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "method": {"type": "string", "required": True},
                                "criteria": {"type": "string", "required": True},
                                "frequency": {"type": "string", "required": True}
                            }
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
        }
    }
) 