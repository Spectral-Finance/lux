from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class HypothesisTestSchema(SignalSchema):
    """Schema for representing scientific hypothesis testing.
    
    This schema defines the structure for scientific hypothesis testing,
    including hypothesis formulation, testing methods, statistical analysis,
    and conclusions.
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "test_id": "test-123456",
            "study_id": "study-789",
            "hypothesis": {
                "null": "There is no difference in growth rates between treatment and control groups",
                "alternative": "Treatment group shows different growth rates compared to control group",
                "type": "difference",
                "variables": ["growth_rate"],
                "groups": ["treatment", "control"]
            },
            "test_design": {
                "method": "t_test",
                "type": "two_sample",
                "parameters": {
                    "alpha": 0.05,
                    "alternative": "two_sided",
                    "paired": false
                },
                "assumptions": [
                    {
                        "name": "normality",
                        "verified": true,
                        "verification_method": "shapiro_wilk_test",
                        "verification_result": {
                            "statistic": 0.98,
                            "p_value": 0.245
                        }
                    }
                ]
            },
            "data_summary": {
                "sample_sizes": {
                    "treatment": 30,
                    "control": 30
                },
                "descriptive_stats": {
                    "treatment": {
                        "mean": 15.6,
                        "std": 2.3,
                        "min": 10.2,
                        "max": 20.1
                    },
                    "control": {
                        "mean": 12.4,
                        "std": 2.1,
                        "min": 8.9,
                        "max": 17.8
                    }
                }
            },
            "test_results": {
                "statistic": 5.67,
                "p_value": 0.00001,
                "effect_size": {
                    "type": "cohens_d",
                    "value": 1.45
                },
                "confidence_interval": {
                    "level": 0.95,
                    "lower": 2.1,
                    "upper": 4.3
                },
                "power": 0.98
            },
            "conclusion": {
                "reject_null": true,
                "interpretation": "Strong evidence to reject the null hypothesis",
                "limitations": [
                    "Sample size relatively small",
                    "Single location study"
                ],
                "recommendations": [
                    "Replicate study with larger sample",
                    "Include multiple locations"
                ]
            },
            "metadata": {
                "researcher": "researcher-456",
                "analysis_date": "2024-04-03T12:34:56Z",
                "software": {
                    "name": "R",
                    "version": "4.2.1",
                    "packages": ["stats", "effectsize"]
                },
                "data_source": "experiment-789",
                "review_status": "peer_reviewed"
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="hypothesis_test",
            version="1.0",
            description="Schema for scientific hypothesis testing",
            schema={
                "type": "object",
                "required": ["timestamp", "test_id", "hypothesis", "test_design", "test_results"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the test was performed"
                    },
                    "test_id": {
                        "type": "string",
                        "description": "Unique identifier for this hypothesis test"
                    },
                    "study_id": {
                        "type": "string",
                        "description": "Identifier of the associated research study"
                    },
                    "hypothesis": {
                        "type": "object",
                        "required": ["null", "alternative", "type"],
                        "properties": {
                            "null": {
                                "type": "string",
                                "description": "Null hypothesis statement"
                            },
                            "alternative": {
                                "type": "string",
                                "description": "Alternative hypothesis statement"
                            },
                            "type": {
                                "type": "string",
                                "enum": ["difference", "association", "equivalence"],
                                "description": "Type of hypothesis being tested"
                            },
                            "variables": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Variables involved in the hypothesis"
                            },
                            "groups": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Groups being compared"
                            }
                        }
                    },
                    "test_design": {
                        "type": "object",
                        "required": ["method", "parameters"],
                        "properties": {
                            "method": {
                                "type": "string",
                                "description": "Statistical test method"
                            },
                            "type": {
                                "type": "string",
                                "enum": ["one_sample", "two_sample", "paired", "anova"],
                                "description": "Type of statistical test"
                            },
                            "parameters": {
                                "type": "object",
                                "properties": {
                                    "alpha": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Significance level"
                                    },
                                    "alternative": {
                                        "type": "string",
                                        "enum": ["two_sided", "less", "greater"],
                                        "description": "Alternative hypothesis direction"
                                    },
                                    "paired": {
                                        "type": "boolean",
                                        "description": "Whether the test is paired"
                                    }
                                }
                            },
                            "assumptions": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "verified"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Name of the assumption"
                                        },
                                        "verified": {
                                            "type": "boolean",
                                            "description": "Whether the assumption was verified"
                                        },
                                        "verification_method": {
                                            "type": "string",
                                            "description": "Method used to verify the assumption"
                                        },
                                        "verification_result": {
                                            "type": "object",
                                            "description": "Results of the verification"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "data_summary": {
                        "type": "object",
                        "properties": {
                            "sample_sizes": {
                                "type": "object",
                                "description": "Sample sizes for each group"
                            },
                            "descriptive_stats": {
                                "type": "object",
                                "description": "Descriptive statistics for each group"
                            }
                        }
                    },
                    "test_results": {
                        "type": "object",
                        "required": ["statistic", "p_value"],
                        "properties": {
                            "statistic": {
                                "type": "number",
                                "description": "Test statistic value"
                            },
                            "p_value": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "P-value of the test"
                            },
                            "effect_size": {
                                "type": "object",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "description": "Type of effect size measure"
                                    },
                                    "value": {
                                        "type": "number",
                                        "description": "Effect size value"
                                    }
                                }
                            },
                            "confidence_interval": {
                                "type": "object",
                                "properties": {
                                    "level": {
                                        "type": "number",
                                        "minimum": 0,
                                        "maximum": 1,
                                        "description": "Confidence level"
                                    },
                                    "lower": {
                                        "type": "number",
                                        "description": "Lower bound"
                                    },
                                    "upper": {
                                        "type": "number",
                                        "description": "Upper bound"
                                    }
                                }
                            },
                            "power": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Statistical power"
                            }
                        }
                    },
                    "conclusion": {
                        "type": "object",
                        "properties": {
                            "reject_null": {
                                "type": "boolean",
                                "description": "Whether to reject the null hypothesis"
                            },
                            "interpretation": {
                                "type": "string",
                                "description": "Interpretation of the results"
                            },
                            "limitations": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Study limitations"
                            },
                            "recommendations": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Recommendations for future research"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "researcher": {
                                "type": "string",
                                "description": "Identifier of the researcher"
                            },
                            "analysis_date": {
                                "type": "string",
                                "format": "date-time",
                                "description": "When the analysis was performed"
                            },
                            "software": {
                                "type": "object",
                                "properties": {
                                    "name": {
                                        "type": "string",
                                        "description": "Software name"
                                    },
                                    "version": {
                                        "type": "string",
                                        "description": "Software version"
                                    },
                                    "packages": {
                                        "type": "array",
                                        "items": {
                                            "type": "string"
                                        },
                                        "description": "Software packages used"
                                    }
                                }
                            },
                            "data_source": {
                                "type": "string",
                                "description": "Source of the analyzed data"
                            },
                            "review_status": {
                                "type": "string",
                                "enum": ["draft", "peer_reviewed", "published"],
                                "description": "Review status of the analysis"
                            }
                        }
                    }
                }
            }
        ) 