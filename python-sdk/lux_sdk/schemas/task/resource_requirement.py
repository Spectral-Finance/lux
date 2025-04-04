"""
Schema for task resource requirements.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ResourceRequirementSchema(SignalSchema):
    """Schema for representing task resource requirements.
    
    This schema defines the structure for representing resource requirements for tasks,
    including computational, network, software, human, data, and financial resources.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "requirement_id": "req_20240403_153000",
            "task_id": "task_789",
            "computational_resources": {
                "cpu": {
                    "cores": 4,
                    "architecture": "x86_64",
                    "min_frequency": "2.5GHz",
                    "features": ["AVX2", "SSE4.2"]
                },
                "memory": {
                    "min_ram": "16GB",
                    "recommended_ram": "32GB",
                    "swap_space": "8GB"
                },
                "storage": {
                    "capacity": "500GB",
                    "type": "SSD",
                    "iops": 10000,
                    "throughput": "500MB/s"
                },
                "gpu": {
                    "memory": "8GB",
                    "cuda_compute": "7.5",
                    "features": ["CUDA", "TensorCores"]
                }
            },
            "network_resources": {
                "bandwidth": "1Gbps",
                "latency": "50ms",
                "protocols": ["TCP/IP", "HTTP/2"],
                "ports": [80, 443],
                "firewall_rules": ["allow_outbound_443"]
            },
            "software_resources": [{
                "name": "TensorFlow",
                "version": "2.8.0",
                "type": "library",
                "installation": {
                    "method": "pip",
                    "source": "pypi",
                    "dependencies": ["numpy>=1.19.2"]
                },
                "configuration": {
                    "gpu_memory_growth": true,
                    "mixed_precision": true
                }
            }],
            "human_resources": [{
                "role": "ML Engineer",
                "count": 2,
                "skills": ["Python", "TensorFlow", "MLOps"],
                "experience_level": "senior",
                "availability": {
                    "start_date": "2024-04-03",
                    "end_date": "2024-06-03",
                    "hours_per_week": 40,
                    "time_zone": "UTC-8"
                },
                "certifications": ["AWS ML Specialty"]
            }],
            "data_resources": [{
                "dataset_id": "dataset_123",
                "name": "Training Dataset",
                "type": "structured",
                "format": "parquet",
                "size": "100GB",
                "access_level": "read_only",
                "location": "s3://bucket/path",
                "requirements": {
                    "preprocessing": true,
                    "validation": true
                }
            }],
            "financial_resources": {
                "budget": {
                    "amount": 50000,
                    "currency": "USD",
                    "period": "monthly",
                    "breakdown": {
                        "infrastructure": 30000,
                        "licenses": 10000,
                        "personnel": 10000
                    }
                },
                "funding_source": "project_budget",
                "cost_constraints": {
                    "max_hourly_rate": 100,
                    "contingency": 0.1
                }
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "resource_planner",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "draft",
                "priority": "high",
                "tags": ["ml_project", "resource_intensive"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="resource_requirement",
            version="1.0",
            description="Schema for representing task resource requirements",
            schema={
                "type": "object",
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the resource requirement"
                    },
                    "requirement_id": {
                        "type": "string",
                        "description": "Unique identifier for the resource requirement"
                    },
                    "task_id": {
                        "type": "string",
                        "description": "Identifier of the associated task"
                    },
                    "computational_resources": {
                        "type": "object",
                        "description": "Required computational resources",
                        "properties": {
                            "cpu": {
                                "type": "object",
                                "description": "CPU requirements",
                                "properties": {
                                    "cores": {
                                        "type": "integer",
                                        "minimum": 1,
                                        "description": "Number of CPU cores"
                                    },
                                    "architecture": {
                                        "type": "string",
                                        "description": "CPU architecture"
                                    },
                                    "min_frequency": {
                                        "type": "string",
                                        "description": "Minimum CPU frequency"
                                    },
                                    "features": {
                                        "type": "array",
                                        "description": "Required CPU features",
                                        "items": {"type": "string"}
                                    }
                                }
                            },
                            "memory": {
                                "type": "object",
                                "description": "Memory requirements",
                                "properties": {
                                    "min_ram": {
                                        "type": "string",
                                        "description": "Minimum RAM required"
                                    },
                                    "recommended_ram": {
                                        "type": "string",
                                        "description": "Recommended RAM"
                                    },
                                    "swap_space": {
                                        "type": "string",
                                        "description": "Required swap space"
                                    }
                                }
                            },
                            "storage": {
                                "type": "object",
                                "description": "Storage requirements",
                                "properties": {
                                    "capacity": {
                                        "type": "string",
                                        "description": "Required storage capacity"
                                    },
                                    "type": {
                                        "type": "string",
                                        "enum": ["HDD", "SSD", "NVMe"],
                                        "description": "Storage type"
                                    },
                                    "iops": {
                                        "type": "integer",
                                        "description": "Required IOPS"
                                    },
                                    "throughput": {
                                        "type": "string",
                                        "description": "Required throughput"
                                    }
                                }
                            },
                            "gpu": {
                                "type": "object",
                                "description": "GPU requirements",
                                "properties": {
                                    "memory": {
                                        "type": "string",
                                        "description": "Required GPU memory"
                                    },
                                    "cuda_compute": {
                                        "type": "string",
                                        "description": "Required CUDA compute capability"
                                    },
                                    "features": {
                                        "type": "array",
                                        "description": "Required GPU features",
                                        "items": {"type": "string"}
                                    }
                                }
                            }
                        }
                    },
                    "network_resources": {
                        "type": "object",
                        "description": "Required network resources",
                        "properties": {
                            "bandwidth": {
                                "type": "string",
                                "description": "Required bandwidth"
                            },
                            "latency": {
                                "type": "string",
                                "description": "Maximum acceptable latency"
                            },
                            "protocols": {
                                "type": "array",
                                "description": "Required network protocols",
                                "items": {"type": "string"}
                            },
                            "ports": {
                                "type": "array",
                                "description": "Required network ports",
                                "items": {"type": "integer"}
                            },
                            "firewall_rules": {
                                "type": "array",
                                "description": "Required firewall rules",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "software_resources": {
                        "type": "array",
                        "description": "Required software resources",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Software name"
                                },
                                "version": {
                                    "type": "string",
                                    "description": "Required version"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Software type"
                                },
                                "installation": {
                                    "type": "object",
                                    "properties": {
                                        "method": {
                                            "type": "string",
                                            "description": "Installation method"
                                        },
                                        "source": {
                                            "type": "string",
                                            "description": "Installation source"
                                        },
                                        "dependencies": {
                                            "type": "array",
                                            "description": "Required dependencies",
                                            "items": {"type": "string"}
                                        }
                                    }
                                },
                                "configuration": {
                                    "type": "object",
                                    "description": "Software configuration"
                                }
                            },
                            "required": ["name", "version", "type"]
                        }
                    },
                    "human_resources": {
                        "type": "array",
                        "description": "Required human resources",
                        "items": {
                            "type": "object",
                            "properties": {
                                "role": {
                                    "type": "string",
                                    "description": "Role title"
                                },
                                "count": {
                                    "type": "integer",
                                    "minimum": 1,
                                    "description": "Number of people required"
                                },
                                "skills": {
                                    "type": "array",
                                    "description": "Required skills",
                                    "items": {"type": "string"}
                                },
                                "experience_level": {
                                    "type": "string",
                                    "description": "Required experience level"
                                },
                                "availability": {
                                    "type": "object",
                                    "properties": {
                                        "start_date": {
                                            "type": "string",
                                            "format": "date",
                                            "description": "Start date"
                                        },
                                        "end_date": {
                                            "type": "string",
                                            "format": "date",
                                            "description": "End date"
                                        },
                                        "hours_per_week": {
                                            "type": "integer",
                                            "description": "Required hours per week"
                                        },
                                        "time_zone": {
                                            "type": "string",
                                            "description": "Required time zone"
                                        }
                                    },
                                    "required": ["start_date", "end_date", "hours_per_week"]
                                },
                                "certifications": {
                                    "type": "array",
                                    "description": "Required certifications",
                                    "items": {"type": "string"}
                                }
                            },
                            "required": ["role", "count", "skills", "experience_level"]
                        }
                    },
                    "data_resources": {
                        "type": "array",
                        "description": "Required data resources",
                        "items": {
                            "type": "object",
                            "properties": {
                                "dataset_id": {
                                    "type": "string",
                                    "description": "Dataset identifier"
                                },
                                "name": {
                                    "type": "string",
                                    "description": "Dataset name"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Data type"
                                },
                                "format": {
                                    "type": "string",
                                    "description": "Data format"
                                },
                                "size": {
                                    "type": "string",
                                    "description": "Dataset size"
                                },
                                "access_level": {
                                    "type": "string",
                                    "description": "Required access level"
                                },
                                "location": {
                                    "type": "string",
                                    "description": "Data location"
                                },
                                "requirements": {
                                    "type": "object",
                                    "description": "Data requirements"
                                }
                            },
                            "required": ["dataset_id", "name", "type", "format", "access_level"]
                        }
                    },
                    "financial_resources": {
                        "type": "object",
                        "description": "Required financial resources",
                        "properties": {
                            "budget": {
                                "type": "object",
                                "properties": {
                                    "amount": {
                                        "type": "number",
                                        "description": "Budget amount"
                                    },
                                    "currency": {
                                        "type": "string",
                                        "description": "Currency code"
                                    },
                                    "period": {
                                        "type": "string",
                                        "description": "Budget period"
                                    },
                                    "breakdown": {
                                        "type": "object",
                                        "description": "Budget breakdown"
                                    }
                                },
                                "required": ["amount", "currency", "period"]
                            },
                            "funding_source": {
                                "type": "string",
                                "description": "Source of funding"
                            },
                            "cost_constraints": {
                                "type": "object",
                                "description": "Cost constraints"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Creator identifier"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Schema version"
                            },
                            "status": {
                                "type": "string",
                                "description": "Current status"
                            },
                            "priority": {
                                "type": "string",
                                "description": "Priority level"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Resource tags",
                                "items": {"type": "string"}
                            }
                        }
                    }
                },
                "required": ["timestamp", "requirement_id", "task_id"]
            }
        )