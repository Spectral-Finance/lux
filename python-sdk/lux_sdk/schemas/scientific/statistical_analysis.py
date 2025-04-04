"""
Statistical Analysis Schema

This schema defines the structure for statistical analysis in scientific research,
including data analysis, hypothesis testing, and statistical methods.
"""

from lux_sdk.signals import SignalSchema

StatisticalAnalysisSchema = SignalSchema(
    name="statistical_analysis",
    version="1.0",
    description="Schema for statistical analysis in scientific research",
    schema={
        "type": "object",
        "description": "Schema for statistical analysis and methods",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "The timestamp when the analysis was performed"
            },
            "analysis_id": {
                "type": "string",
                "description": "Unique identifier for this statistical analysis"
            },
            "dataset_id": {
                "type": "string",
                "description": "Reference to the dataset being analyzed"
            },
            "analysis_type": {
                "type": "string",
                "enum": [
                    "descriptive",
                    "inferential",
                    "regression",
                    "correlation",
                    "time_series",
                    "multivariate",
                    "bayesian",
                    "nonparametric"
                ],
                "description": "Type of statistical analysis"
            },
            "variables": {
                "type": "array",
                "description": "Variables included in the analysis",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "type": {
                            "type": "string",
                            "enum": ["continuous", "discrete", "categorical", "ordinal"]
                        },
                        "role": {
                            "type": "string",
                            "enum": ["dependent", "independent", "covariate", "control"]
                        },
                        "summary_statistics": {
                            "type": "object",
                            "properties": {
                                "mean": {"type": "number"},
                                "median": {"type": "number"},
                                "mode": {"type": "array", "items": {"type": "number"}},
                                "std_dev": {"type": "number"},
                                "variance": {"type": "number"},
                                "range": {
                                    "type": "object",
                                    "properties": {
                                        "min": {"type": "number"},
                                        "max": {"type": "number"}
                                    }
                                }
                            }
                        }
                    },
                    "required": ["name", "type", "role"]
                }
            },
            "methods": {
                "type": "array",
                "description": "Statistical methods used in the analysis",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "parameters": {"type": "object"},
                        "assumptions": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "name": {"type": "string"},
                                    "verified": {"type": "boolean"},
                                    "test_results": {"type": "object"}
                                }
                            }
                        }
                    },
                    "required": ["name", "parameters"]
                }
            },
            "results": {
                "type": "object",
                "description": "Results of the statistical analysis",
                "properties": {
                    "test_statistics": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "value": {"type": "number"},
                                "degrees_of_freedom": {"type": "number"},
                                "p_value": {"type": "number"}
                            }
                        }
                    },
                    "effect_sizes": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "value": {"type": "number"},
                                "confidence_interval": {
                                    "type": "object",
                                    "properties": {
                                        "lower": {"type": "number"},
                                        "upper": {"type": "number"},
                                        "level": {"type": "number"}
                                    }
                                }
                            }
                        }
                    },
                    "model_fit": {
                        "type": "object",
                        "properties": {
                            "r_squared": {"type": "number"},
                            "adjusted_r_squared": {"type": "number"},
                            "aic": {"type": "number"},
                            "bic": {"type": "number"}
                        }
                    }
                }
            },
            "visualizations": {
                "type": "array",
                "description": "References to generated visualizations",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {"type": "string"},
                        "title": {"type": "string"},
                        "url": {"type": "string"},
                        "description": {"type": "string"}
                    }
                }
            },
            "metadata": {
                "type": "object",
                "description": "Additional information about the statistical analysis",
                "properties": {
                    "analyst": {"type": "string"},
                    "analysis_date": {"type": "string", "format": "date"},
                    "software": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "version": {"type": "string"},
                            "packages": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "name": {"type": "string"},
                                        "version": {"type": "string"}
                                    }
                                }
                            }
                        }
                    },
                    "reproducibility_info": {
                        "type": "object",
                        "properties": {
                            "random_seed": {"type": "integer"},
                            "data_preprocessing": {"type": "string"},
                            "code_repository": {"type": "string"}
                        }
                    }
                },
                "required": ["analyst", "analysis_date"]
            }
        },
        "required": [
            "timestamp",
            "analysis_id",
            "dataset_id",
            "analysis_type",
            "variables",
            "methods",
            "results",
            "metadata"
        ]
    }) 