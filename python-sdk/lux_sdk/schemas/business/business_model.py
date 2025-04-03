"""
Business Model Schema

This schema represents business model components and analysis, including value proposition,
customer segments, revenue streams, and key resources.
"""

from lux_sdk.signals import SignalSchema

BusinessModelSchema = SignalSchema(
    name="business_model",
    version="1.0",
    description="Schema for documenting and analyzing business models",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "model_id": {
                "type": "string",
                "description": "Unique identifier for this business model"
            },
            "name": {
                "type": "string",
                "description": "Name of the business model"
            },
            "industry": {
                "type": "string",
                "description": "Industry or sector"
            },
            "value_proposition": {
                "type": "object",
                "properties": {
                    "core_value": {
                        "type": "string",
                        "description": "Primary value offered to customers"
                    },
                    "unique_features": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Distinctive features or benefits"
                        }
                    },
                    "competitive_advantages": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "advantage": {
                                    "type": "string",
                                    "description": "Description of competitive advantage"
                                },
                                "sustainability": {
                                    "type": "string",
                                    "description": "How sustainable this advantage is"
                                }
                            },
                            "required": ["advantage"]
                        }
                    }
                },
                "required": ["core_value"]
            },
            "customer_segments": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "segment_id": {
                            "type": "string",
                            "description": "Identifier for this segment"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the segment"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the segment"
                        },
                        "characteristics": {
                            "type": "object",
                            "properties": {
                                "demographics": {
                                    "type": "object",
                                    "description": "Demographic characteristics"
                                },
                                "behaviors": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Key behavioral patterns"
                                    }
                                },
                                "needs": {
                                    "type": "array",
                                    "items": {
                                        "type": "string",
                                        "description": "Primary needs and pain points"
                                    }
                                }
                            }
                        },
                        "market_size": {
                            "type": "object",
                            "properties": {
                                "tam": {
                                    "type": "number",
                                    "description": "Total addressable market"
                                },
                                "sam": {
                                    "type": "number",
                                    "description": "Serviceable addressable market"
                                },
                                "som": {
                                    "type": "number",
                                    "description": "Serviceable obtainable market"
                                }
                            }
                        }
                    },
                    "required": ["segment_id", "name", "description"]
                }
            },
            "channels": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "channel_id": {
                            "type": "string",
                            "description": "Identifier for this channel"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["direct", "indirect", "online", "physical", "partner"],
                            "description": "Type of channel"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the channel"
                        },
                        "cost_structure": {
                            "type": "object",
                            "description": "Cost breakdown for this channel"
                        },
                        "effectiveness": {
                            "type": "object",
                            "properties": {
                                "reach": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Channel reach score"
                                },
                                "conversion": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Channel conversion rate"
                                }
                            }
                        }
                    },
                    "required": ["channel_id", "type", "description"]
                }
            },
            "revenue_streams": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "stream_id": {
                            "type": "string",
                            "description": "Identifier for this revenue stream"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["subscription", "usage_fee", "licensing", "asset_sale", "advertising", "other"],
                            "description": "Type of revenue stream"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the revenue stream"
                        },
                        "pricing_model": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["fixed", "dynamic", "tiered", "usage_based", "market_based"],
                                    "description": "Type of pricing model"
                                },
                                "structure": {
                                    "type": "object",
                                    "description": "Detailed pricing structure"
                                }
                            },
                            "required": ["type"]
                        },
                        "projections": {
                            "type": "object",
                            "properties": {
                                "annual_revenue": {
                                    "type": "number",
                                    "description": "Projected annual revenue"
                                },
                                "growth_rate": {
                                    "type": "number",
                                    "description": "Expected growth rate"
                                }
                            }
                        }
                    },
                    "required": ["stream_id", "type", "description"]
                }
            },
            "key_resources": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "resource_id": {
                            "type": "string",
                            "description": "Identifier for this resource"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["physical", "intellectual", "human", "financial"],
                            "description": "Type of resource"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the resource"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the resource"
                        },
                        "criticality": {
                            "type": "string",
                            "enum": ["low", "medium", "high", "critical"],
                            "description": "How critical this resource is"
                        }
                    },
                    "required": ["resource_id", "type", "name", "criticality"]
                }
            },
            "cost_structure": {
                "type": "object",
                "properties": {
                    "fixed_costs": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "category": {
                                    "type": "string",
                                    "description": "Cost category"
                                },
                                "amount": {
                                    "type": "number",
                                    "description": "Annual cost amount"
                                }
                            },
                            "required": ["category", "amount"]
                        }
                    },
                    "variable_costs": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "category": {
                                    "type": "string",
                                    "description": "Cost category"
                                },
                                "unit_cost": {
                                    "type": "number",
                                    "description": "Cost per unit"
                                },
                                "scaling_factor": {
                                    "type": "string",
                                    "description": "How cost scales with volume"
                                }
                            },
                            "required": ["category", "unit_cost"]
                        }
                    }
                }
            },
            "key_metrics": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "metric_id": {
                            "type": "string",
                            "description": "Identifier for this metric"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the metric"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of what is measured"
                        },
                        "unit": {
                            "type": "string",
                            "description": "Unit of measurement"
                        },
                        "target": {
                            "type": "number",
                            "description": "Target value"
                        },
                        "current": {
                            "type": "number",
                            "description": "Current value"
                        }
                    },
                    "required": ["metric_id", "name", "description"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {
                        "type": "string",
                        "description": "ID of model creator"
                    },
                    "creation_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the model was created"
                    },
                    "last_modified": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the model was last modified"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the business model"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["draft", "review", "approved", "archived"],
                        "description": "Current status of the model"
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
        "required": ["timestamp", "model_id", "name", "industry", "value_proposition", "customer_segments", "revenue_streams"]
    }
) 