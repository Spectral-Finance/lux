"""
Environmental Impact Schema

This schema represents environmental impact assessments and monitoring data,
including resource consumption, emissions, and sustainability metrics.
"""

from lux_sdk.signals import SignalSchema

EnvironmentalImpactSchema = SignalSchema(
    name="environmental_impact",
    version="1.0",
    description="Schema for assessing and monitoring environmental impacts",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "assessment_id": {
                "type": "string",
                "description": "Unique identifier for this assessment"
            },
            "scope": {
                "type": "object",
                "properties": {
                    "organization": {
                        "type": "string",
                        "description": "Organization being assessed"
                    },
                    "facility": {
                        "type": "string",
                        "description": "Specific facility or location"
                    },
                    "time_period": {
                        "type": "object",
                        "properties": {
                            "start_date": {
                                "type": "string",
                                "format": "date-time"
                            },
                            "end_date": {
                                "type": "string",
                                "format": "date-time"
                            }
                        },
                        "required": ["start_date", "end_date"]
                    }
                },
                "required": ["organization", "time_period"]
            },
            "energy_consumption": {
                "type": "object",
                "properties": {
                    "electricity": {
                        "type": "object",
                        "properties": {
                            "total_kwh": {
                                "type": "number",
                                "description": "Total electricity consumption in kWh"
                            },
                            "renewable_percentage": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "Percentage from renewable sources"
                            },
                            "grid_sources": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "source": {
                                            "type": "string",
                                            "description": "Energy source"
                                        },
                                        "percentage": {
                                            "type": "number",
                                            "description": "Percentage contribution"
                                        }
                                    }
                                }
                            }
                        },
                        "required": ["total_kwh"]
                    },
                    "fuel": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of fuel"
                                },
                                "quantity": {
                                    "type": "number",
                                    "description": "Amount consumed"
                                },
                                "unit": {
                                    "type": "string",
                                    "description": "Unit of measurement"
                                }
                            },
                            "required": ["type", "quantity", "unit"]
                        }
                    }
                }
            },
            "emissions": {
                "type": "object",
                "properties": {
                    "greenhouse_gases": {
                        "type": "object",
                        "properties": {
                            "co2": {
                                "type": "number",
                                "description": "CO2 emissions in metric tons"
                            },
                            "ch4": {
                                "type": "number",
                                "description": "Methane emissions in metric tons CO2e"
                            },
                            "n2o": {
                                "type": "number",
                                "description": "N2O emissions in metric tons CO2e"
                            },
                            "other_ghgs": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Name of the gas"
                                        },
                                        "amount": {
                                            "type": "number",
                                            "description": "Amount in metric tons CO2e"
                                        }
                                    }
                                }
                            }
                        },
                        "required": ["co2"]
                    },
                    "air_pollutants": {
                        "type": "object",
                        "properties": {
                            "nox": {
                                "type": "number",
                                "description": "NOx emissions in metric tons"
                            },
                            "sox": {
                                "type": "number",
                                "description": "SOx emissions in metric tons"
                            },
                            "particulate_matter": {
                                "type": "number",
                                "description": "PM emissions in metric tons"
                            }
                        }
                    }
                },
                "required": ["greenhouse_gases"]
            },
            "water_usage": {
                "type": "object",
                "properties": {
                    "total_consumption": {
                        "type": "number",
                        "description": "Total water consumption in cubic meters"
                    },
                    "sources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source": {
                                    "type": "string",
                                    "description": "Water source"
                                },
                                "amount": {
                                    "type": "number",
                                    "description": "Amount in cubic meters"
                                },
                                "quality": {
                                    "type": "string",
                                    "description": "Water quality classification"
                                }
                            },
                            "required": ["source", "amount"]
                        }
                    },
                    "wastewater": {
                        "type": "object",
                        "properties": {
                            "volume": {
                                "type": "number",
                                "description": "Volume in cubic meters"
                            },
                            "treatment_method": {
                                "type": "string",
                                "description": "Treatment method used"
                            }
                        }
                    }
                },
                "required": ["total_consumption"]
            },
            "waste_management": {
                "type": "object",
                "properties": {
                    "total_waste": {
                        "type": "number",
                        "description": "Total waste generated in metric tons"
                    },
                    "categories": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of waste"
                                },
                                "amount": {
                                    "type": "number",
                                    "description": "Amount in metric tons"
                                },
                                "disposal_method": {
                                    "type": "string",
                                    "enum": ["recycling", "landfill", "incineration", "composting", "other"],
                                    "description": "Method of disposal"
                                }
                            },
                            "required": ["type", "amount", "disposal_method"]
                        }
                    },
                    "recycling_rate": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100,
                        "description": "Percentage of waste recycled"
                    }
                },
                "required": ["total_waste", "categories"]
            },
            "biodiversity_impact": {
                "type": "object",
                "properties": {
                    "land_use": {
                        "type": "object",
                        "properties": {
                            "total_area": {
                                "type": "number",
                                "description": "Total land area in square meters"
                            },
                            "habitat_types": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "description": "Type of habitat"
                                        },
                                        "area": {
                                            "type": "number",
                                            "description": "Area in square meters"
                                        },
                                        "status": {
                                            "type": "string",
                                            "description": "Conservation status"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "species_impact": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "species": {
                                    "type": "string",
                                    "description": "Affected species"
                                },
                                "impact_level": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high", "critical"],
                                    "description": "Level of impact"
                                },
                                "mitigation_measures": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Mitigation measures"
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "sustainability_metrics": {
                "type": "object",
                "properties": {
                    "carbon_intensity": {
                        "type": "number",
                        "description": "Carbon intensity per unit of output"
                    },
                    "energy_efficiency": {
                        "type": "number",
                        "description": "Energy efficiency rating"
                    },
                    "water_intensity": {
                        "type": "number",
                        "description": "Water usage per unit of output"
                    },
                    "renewable_ratio": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 100,
                        "description": "Percentage of renewable resource usage"
                    }
                }
            },
            "compliance": {
                "type": "object",
                "properties": {
                    "standards": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Name of standard or regulation"
                                },
                                "compliance_status": {
                                    "type": "string",
                                    "enum": ["compliant", "non_compliant", "partial", "not_applicable"],
                                    "description": "Compliance status"
                                },
                                "details": {
                                    "type": "string",
                                    "description": "Compliance details"
                                }
                            }
                        }
                    },
                    "permits": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "permit_id": {
                                    "type": "string",
                                    "description": "Permit identifier"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Type of permit"
                                },
                                "status": {
                                    "type": "string",
                                    "description": "Current status"
                                },
                                "expiry_date": {
                                    "type": "string",
                                    "format": "date-time"
                                }
                            }
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "assessor": {
                        "type": "string",
                        "description": "ID of the assessor"
                    },
                    "methodology": {
                        "type": "string",
                        "description": "Assessment methodology used"
                    },
                    "data_quality": {
                        "type": "object",
                        "properties": {
                            "completeness": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "Data completeness percentage"
                            },
                            "reliability": {
                                "type": "string",
                                "enum": ["low", "medium", "high"],
                                "description": "Data reliability rating"
                            }
                        }
                    },
                    "verification_status": {
                        "type": "string",
                        "enum": ["unverified", "in_progress", "verified"],
                        "description": "Verification status of the assessment"
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
        "required": ["timestamp", "assessment_id", "scope", "energy_consumption", "emissions", "water_usage", "waste_management"]
    }
) 