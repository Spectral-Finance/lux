"""
Schema for representing inference results from cognitive processes.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class InferenceResultSchema(SignalSchema):
    """Schema for representing inference results from cognitive processes.
    
    This schema defines the structure for documenting and analyzing inference results,
    including input data, inference process, conclusions, and validation.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "inference_id": "inf_123",
            "context_id": "ctx_456",
            "input_data": {
                "premises": [{
                    "statement": "All birds have wings",
                    "confidence": 1.0,
                    "source": "biological taxonomy"
                }, {
                    "statement": "Penguins are birds",
                    "confidence": 1.0,
                    "source": "biological classification"
                }],
                "context_variables": {
                    "domain": "biology",
                    "scope": "animal classification"
                },
                "constraints": [
                    "Consider only living species",
                    "Exclude extinct species"
                ]
            },
            "inference_process": {
                "method": "deductive reasoning",
                "steps": [{
                    "step_id": "step_1",
                    "operation": "syllogistic inference",
                    "intermediate_result": "Penguins have wings"
                }],
                "rules_applied": [
                    "transitive property",
                    "categorical syllogism"
                ]
            },
            "conclusions": [{
                "statement": "Penguins have wings",
                "confidence": 1.0,
                "supporting_evidence": [
                    "Anatomical studies",
                    "Evolutionary evidence"
                ],
                "uncertainty_factors": []
            }],
            "validation": {
                "consistency_check": true,
                "validation_method": "logical verification",
                "validation_results": [{
                    "check_name": "consistency",
                    "passed": true,
                    "details": "No logical contradictions found"
                }]
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "inference_engine_v1",
                "computation_time": 0.5,
                "version": "1.0",
                "tags": ["biology", "classification", "deductive_reasoning"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="inference_result",
            version="1.0",
            description="Schema for representing results of inference processes and logical reasoning",
            schema={
                "type": "object",
                "required": ["timestamp", "inference_id", "context_id", "input_data", "inference_process", "conclusions"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the inference result"
                    },
                    "inference_id": {
                        "type": "string",
                        "description": "Unique identifier for the inference result"
                    },
                    "context_id": {
                        "type": "string",
                        "description": "Identifier of the context in which inference was made"
                    },
                    "input_data": {
                        "type": "object",
                        "description": "Input data used for inference",
                        "required": ["premises"],
                        "properties": {
                            "premises": {
                                "type": "array",
                                "description": "List of premises used in inference",
                                "items": {
                                    "type": "object",
                                    "required": ["statement"],
                                    "properties": {
                                        "statement": {
                                            "type": "string",
                                            "description": "The premise statement"
                                        },
                                        "confidence": {
                                            "type": "number",
                                            "description": "Confidence level in the premise",
                                            "minimum": 0,
                                            "maximum": 1
                                        },
                                        "source": {
                                            "type": "string",
                                            "description": "Source of the premise"
                                        }
                                    }
                                }
                            },
                            "context_variables": {
                                "type": "object",
                                "description": "Relevant contextual variables"
                            },
                            "constraints": {
                                "type": "array",
                                "description": "Constraints applied during inference",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "inference_process": {
                        "type": "object",
                        "description": "Details of the inference process",
                        "required": ["method"],
                        "properties": {
                            "method": {
                                "type": "string",
                                "description": "Method of inference used"
                            },
                            "steps": {
                                "type": "array",
                                "description": "Steps in the inference process",
                                "items": {
                                    "type": "object",
                                    "required": ["step_id", "operation"],
                                    "properties": {
                                        "step_id": {
                                            "type": "string",
                                            "description": "Identifier for the step"
                                        },
                                        "operation": {
                                            "type": "string",
                                            "description": "Operation performed"
                                        },
                                        "intermediate_result": {
                                            "type": "string",
                                            "description": "Result of this step"
                                        }
                                    }
                                }
                            },
                            "rules_applied": {
                                "type": "array",
                                "description": "Logical rules applied",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    },
                    "conclusions": {
                        "type": "array",
                        "description": "Derived conclusions",
                        "items": {
                            "type": "object",
                            "required": ["statement", "confidence"],
                            "properties": {
                                "statement": {
                                    "type": "string",
                                    "description": "The concluded statement"
                                },
                                "confidence": {
                                    "type": "number",
                                    "description": "Confidence level in the conclusion",
                                    "minimum": 0,
                                    "maximum": 1
                                },
                                "supporting_evidence": {
                                    "type": "array",
                                    "description": "Evidence supporting the conclusion",
                                    "items": {
                                        "type": "string"
                                    }
                                },
                                "uncertainty_factors": {
                                    "type": "array",
                                    "description": "Factors contributing to uncertainty",
                                    "items": {
                                        "type": "string"
                                    }
                                }
                            }
                        }
                    },
                    "validation": {
                        "type": "object",
                        "description": "Validation of inference results",
                        "properties": {
                            "consistency_check": {
                                "type": "boolean",
                                "description": "Whether the conclusions are logically consistent"
                            },
                            "validation_method": {
                                "type": "string",
                                "description": "Method used for validation"
                            },
                            "validation_results": {
                                "type": "array",
                                "description": "Results of validation checks",
                                "items": {
                                    "type": "object",
                                    "required": ["check_name", "passed"],
                                    "properties": {
                                        "check_name": {
                                            "type": "string",
                                            "description": "Name of the validation check"
                                        },
                                        "passed": {
                                            "type": "boolean",
                                            "description": "Whether the check passed"
                                        },
                                        "details": {
                                            "type": "string",
                                            "description": "Details about the validation result"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the inference result",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the inference"
                            },
                            "computation_time": {
                                "type": "number",
                                "description": "Time taken for inference in seconds"
                            },
                            "version": {
                                "type": "string",
                                "description": "Version of the inference engine"
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