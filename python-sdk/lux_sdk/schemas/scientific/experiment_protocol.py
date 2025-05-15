"""
Schema for representing scientific experiment protocols and procedures.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ExperimentProtocolSchema(SignalSchema):
    """Schema for representing scientific experiment protocols and procedures.
    
    This schema defines the structure for representing scientific experiment protocols,
    including methodology, variables, controls, and measurement procedures.
    It helps ensure reproducibility and standardization of experimental procedures.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "protocol_id": "prot_20240403_153000",
            "experiment_id": "exp_789",
            "methodology": {
                "name": "Double-blind randomized control trial",
                "description": "Testing efficacy of treatment X vs placebo",
                "type": "quantitative",
                "design": {
                    "study_type": "experimental",
                    "control_type": "placebo_controlled",
                    "blinding": "double_blind",
                    "randomization": true,
                    "replication": 3
                }
            },
            "variables": {
                "independent": [{
                    "name": "treatment_dosage",
                    "type": "continuous",
                    "unit": "mg",
                    "levels": [10, 20, 30],
                    "control_value": 0
                }],
                "dependent": [{
                    "name": "symptom_severity",
                    "type": "ordinal",
                    "scale": [0, 1, 2, 3, 4, 5],
                    "measurement_method": "standardized_assessment",
                    "precision": 0.1
                }],
                "controlled": [{
                    "name": "room_temperature",
                    "type": "continuous",
                    "unit": "celsius",
                    "target_value": 22,
                    "tolerance": 0.5
                }]
            },
            "procedures": [{
                "step_id": "step_1",
                "name": "Sample preparation",
                "description": "Prepare samples according to standard protocol",
                "duration": "30 minutes",
                "conditions": [{
                    "parameter": "temperature",
                    "requirement": "room temperature",
                    "tolerance": 2
                }],
                "safety_measures": ["wear gloves", "use fume hood"],
                "quality_controls": ["verify sample purity", "check temperature"]
            }],
            "measurements": [{
                "variable": "symptom_severity",
                "method": "standardized_assessment",
                "instrument": {
                    "name": "Assessment Tool v2",
                    "type": "questionnaire",
                    "calibration": {"frequency": "monthly"},
                    "settings": {"scale": "0-5"}
                },
                "sampling": {
                    "method": "random",
                    "frequency": "daily",
                    "size": 100,
                    "conditions": ["before treatment", "after treatment"]
                },
                "data_recording": {
                    "format": "numeric",
                    "precision": 0.1,
                    "units": "score",
                    "validation": ["range check", "outlier detection"]
                }
            }],
            "quality_assurance": {
                "controls": [{
                    "type": "calibration",
                    "frequency": "daily",
                    "criteria": ["within tolerance range"],
                    "actions": ["recalibrate if outside range"]
                }],
                "validation": [{
                    "stage": "data collection",
                    "method": "double entry",
                    "criteria": ["100% match"]
                }],
                "documentation": [{
                    "type": "protocol_log",
                    "content": ["procedure steps", "deviations"],
                    "format": "digital",
                    "frequency": "per session"
                }]
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "researcher_123",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "active",
                "review_history": [{
                    "reviewer": "reviewer_456",
                    "date": "2024-04-03T15:30:00Z",
                    "comments": "Protocol meets standards",
                    "status": "approved"
                }],
                "references": ["protocol_v1", "SOP_123"],
                "tags": ["clinical trial", "double blind", "treatment study"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="experiment_protocol",
            version="1.0",
            description="Schema for representing scientific experiment protocols and procedures",
            schema={
                "type": "object",
                "required": ["timestamp", "protocol_id", "experiment_id", "methodology", "variables", "procedures"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the protocol record"
                    },
                    "protocol_id": {
                        "type": "string",
                        "description": "Unique identifier for the protocol"
                    },
                    "experiment_id": {
                        "type": "string",
                        "description": "Identifier of the associated experiment"
                    },
                    "methodology": {
                        "type": "object",
                        "required": ["name", "description", "type", "design"],
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Protocol name"
                            },
                            "description": {
                                "type": "string",
                                "description": "Detailed protocol description"
                            },
                            "type": {
                                "type": "string",
                                "enum": ["quantitative", "qualitative", "mixed"],
                                "description": "Research type"
                            },
                            "design": {
                                "type": "object",
                                "required": ["study_type", "control_type"],
                                "properties": {
                                    "study_type": {
                                        "type": "string",
                                        "enum": ["experimental", "observational", "quasi-experimental"],
                                        "description": "Type of study"
                                    },
                                    "control_type": {
                                        "type": "string",
                                        "enum": ["placebo_controlled", "active_controlled", "no_control"],
                                        "description": "Type of control used"
                                    },
                                    "blinding": {
                                        "type": "string",
                                        "enum": ["single_blind", "double_blind", "triple_blind", "open_label"],
                                        "description": "Blinding method"
                                    },
                                    "randomization": {
                                        "type": "boolean",
                                        "description": "Whether randomization is used"
                                    },
                                    "replication": {
                                        "type": "integer",
                                        "minimum": 1,
                                        "description": "Number of replications"
                                    }
                                }
                            }
                        }
                    },
                    "variables": {
                        "type": "object",
                        "required": ["independent", "dependent"],
                        "properties": {
                            "independent": {
                                "type": "array",
                                "description": "Independent variables",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "type"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Variable name"
                                        },
                                        "type": {
                                            "type": "string",
                                            "enum": ["continuous", "discrete", "categorical", "ordinal"],
                                            "description": "Variable type"
                                        },
                                        "unit": {
                                            "type": "string",
                                            "description": "Unit of measurement"
                                        },
                                        "levels": {
                                            "type": "array",
                                            "description": "Treatment levels"
                                        },
                                        "control_value": {
                                            "type": "number",
                                            "description": "Control group value"
                                        }
                                    }
                                }
                            },
                            "dependent": {
                                "type": "array",
                                "description": "Dependent variables",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "type", "measurement_method"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Variable name"
                                        },
                                        "type": {
                                            "type": "string",
                                            "enum": ["continuous", "discrete", "categorical", "ordinal"],
                                            "description": "Variable type"
                                        },
                                        "scale": {
                                            "type": "array",
                                            "description": "Measurement scale"
                                        },
                                        "measurement_method": {
                                            "type": "string",
                                            "description": "Method of measurement"
                                        },
                                        "precision": {
                                            "type": "number",
                                            "minimum": 0,
                                            "description": "Required measurement precision"
                                        }
                                    }
                                }
                            },
                            "controlled": {
                                "type": "array",
                                "description": "Controlled variables",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "type", "target_value"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Variable name"
                                        },
                                        "type": {
                                            "type": "string",
                                            "enum": ["continuous", "discrete", "categorical", "ordinal"],
                                            "description": "Variable type"
                                        },
                                        "unit": {
                                            "type": "string",
                                            "description": "Unit of measurement"
                                        },
                                        "target_value": {
                                            "type": "number",
                                            "description": "Target value"
                                        },
                                        "tolerance": {
                                            "type": "number",
                                            "minimum": 0,
                                            "description": "Acceptable deviation"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "procedures": {
                        "type": "array",
                        "description": "Experimental procedures",
                        "items": {
                            "type": "object",
                            "required": ["step_id", "name", "description"],
                            "properties": {
                                "step_id": {
                                    "type": "string",
                                    "description": "Step identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Step name"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Detailed instructions"
                                },
                                "duration": {
                                    "type": "string",
                                    "description": "Expected duration"
                                },
                                "conditions": {
                                    "type": "array",
                                    "description": "Required conditions",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "parameter": {
                                                "type": "string",
                                                "description": "Condition parameter"
                                            },
                                            "requirement": {
                                                "type": "string",
                                                "description": "Required value or state"
                                            },
                                            "tolerance": {
                                                "type": "number",
                                                "description": "Acceptable deviation"
                                            }
                                        }
                                    }
                                },
                                "safety_measures": {
                                    "type": "array",
                                    "description": "Safety requirements",
                                    "items": {"type": "string"}
                                },
                                "quality_controls": {
                                    "type": "array",
                                    "description": "Quality control measures",
                                    "items": {"type": "string"}
                                }
                            }
                        }
                    },
                    "measurements": {
                        "type": "array",
                        "description": "Measurement protocols",
                        "items": {
                            "type": "object",
                            "required": ["variable", "method"],
                            "properties": {
                                "variable": {
                                    "type": "string",
                                    "description": "Variable being measured"
                                },
                                "method": {
                                    "type": "string",
                                    "description": "Measurement method"
                                },
                                "instrument": {
                                    "type": "object",
                                    "description": "Measurement instrument",
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Instrument name"
                                        },
                                        "type": {
                                            "type": "string",
                                            "description": "Instrument type"
                                        },
                                        "calibration": {
                                            "type": "object",
                                            "description": "Calibration requirements"
                                        },
                                        "settings": {
                                            "type": "object",
                                            "description": "Instrument settings"
                                        }
                                    }
                                },
                                "sampling": {
                                    "type": "object",
                                    "description": "Sampling protocol",
                                    "properties": {
                                        "method": {
                                            "type": "string",
                                            "description": "Sampling method"
                                        },
                                        "frequency": {
                                            "type": "string",
                                            "description": "Sampling frequency"
                                        },
                                        "size": {
                                            "type": "integer",
                                            "minimum": 1,
                                            "description": "Sample size"
                                        },
                                        "conditions": {
                                            "type": "array",
                                            "description": "Sampling conditions",
                                            "items": {"type": "string"}
                                        }
                                    }
                                },
                                "data_recording": {
                                    "type": "object",
                                    "description": "Data recording protocol",
                                    "properties": {
                                        "format": {
                                            "type": "string",
                                            "description": "Data format"
                                        },
                                        "precision": {
                                            "type": "number",
                                            "minimum": 0,
                                            "description": "Required precision"
                                        },
                                        "units": {
                                            "type": "string",
                                            "description": "Units of measurement"
                                        },
                                        "validation": {
                                            "type": "array",
                                            "description": "Validation checks",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "quality_assurance": {
                        "type": "object",
                        "description": "Quality assurance measures",
                        "properties": {
                            "controls": {
                                "type": "array",
                                "description": "Quality control measures",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "description": "Control type"
                                        },
                                        "frequency": {
                                            "type": "string",
                                            "description": "Control frequency"
                                        },
                                        "criteria": {
                                            "type": "array",
                                            "description": "Acceptance criteria",
                                            "items": {"type": "string"}
                                        },
                                        "actions": {
                                            "type": "array",
                                            "description": "Required actions",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            },
                            "validation": {
                                "type": "array",
                                "description": "Validation procedures",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "stage": {
                                            "type": "string",
                                            "description": "Validation stage"
                                        },
                                        "method": {
                                            "type": "string",
                                            "description": "Validation method"
                                        },
                                        "criteria": {
                                            "type": "array",
                                            "description": "Success criteria",
                                            "items": {"type": "string"}
                                        }
                                    }
                                }
                            },
                            "documentation": {
                                "type": "array",
                                "description": "Required documentation",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "description": "Document type"
                                        },
                                        "content": {
                                            "type": "array",
                                            "description": "Required content",
                                            "items": {"type": "string"}
                                        },
                                        "format": {
                                            "type": "string",
                                            "description": "Document format"
                                        },
                                        "frequency": {
                                            "type": "string",
                                            "description": "Update frequency"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the protocol",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Protocol creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Protocol version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "under_review", "active", "deprecated"],
                                "description": "Protocol status"
                            },
                            "review_history": {
                                "type": "array",
                                "description": "Protocol review history",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "reviewer": {
                                            "type": "string",
                                            "description": "Reviewer identifier"
                                        },
                                        "date": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Review date"
                                        },
                                        "comments": {
                                            "type": "string",
                                            "description": "Review comments"
                                        },
                                        "status": {
                                            "type": "string",
                                            "enum": ["pending", "approved", "rejected", "needs_revision"],
                                            "description": "Review status"
                                        }
                                    }
                                }
                            },
                            "references": {
                                "type": "array",
                                "description": "Related protocols and documents",
                                "items": {"type": "string"}
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