"""
Schema for market analysis and insights.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class MarketAnalysisSchema(SignalSchema):
    """Schema for representing comprehensive market analysis and insights.
    
    This schema defines the structure for market analysis reports, including
    market size, competitive landscape, customer analysis, market drivers,
    opportunities, and strategic recommendations.
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "analysis_id": "ma-123456",
            "organization_id": "org-789",
            "market_overview": {
                "title": "Global SaaS Market Analysis 2024",
                "description": "Comprehensive analysis of the global SaaS market",
                "scope": "Global enterprise SaaS solutions",
                "time_period": {
                    "start_date": "2024-01-01",
                    "end_date": "2024-12-31"
                },
                "geography": {
                    "regions": ["North America", "Europe", "APAC"],
                    "countries": ["USA", "UK", "Germany", "Japan"],
                    "markets": ["Enterprise Software", "Cloud Services"]
                },
                "industry": {
                    "sector": "Technology",
                    "subsectors": ["Software", "Cloud Computing"],
                    "verticals": ["Enterprise", "SMB"]
                }
            },
            "market_size": {
                "total_market": {
                    "value": 150.0,
                    "currency": "USD",
                    "year": 2024,
                    "cagr": 12.5
                },
                "segmentation": [
                    {
                        "segment": "Enterprise Solutions",
                        "value": 75.0,
                        "share": 50.0,
                        "growth_rate": 15.0
                    }
                ],
                "forecasts": [
                    {
                        "year": 2025,
                        "value": 168.75,
                        "growth": 12.5,
                        "assumptions": [
                            "Continued digital transformation",
                            "Increasing cloud adoption"
                        ]
                    }
                ]
            },
            "competitive_landscape": {
                "competitors": [
                    {
                        "name": "Company A",
                        "market_share": 25.0,
                        "strengths": ["Strong R&D", "Global presence"],
                        "weaknesses": ["High pricing", "Complex implementation"],
                        "strategy": "Premium positioning",
                        "positioning": "Enterprise market leader"
                    }
                ],
                "market_concentration": {
                    "type": "Oligopoly",
                    "hhi": 2500,
                    "cr4": 75.0
                },
                "entry_barriers": [
                    {
                        "barrier": "High initial investment",
                        "impact": "High",
                        "mitigation": "Strategic partnerships"
                    }
                ]
            },
            "customer_analysis": {
                "segments": [
                    {
                        "name": "Enterprise",
                        "description": "Large organizations",
                        "size": 1000,
                        "demographics": {
                            "industry": "Various",
                            "size": "1000+ employees"
                        },
                        "needs": ["Scalability", "Security"],
                        "behavior": {
                            "purchase_cycle": "6-12 months",
                            "decision_makers": ["CTO", "CIO"]
                        },
                        "value": 100000000
                    }
                ],
                "preferences": [
                    {
                        "attribute": "Security",
                        "importance": 9.5,
                        "trends": ["Increasing focus on compliance"]
                    }
                ],
                "journey": {
                    "touchpoints": ["Website", "Sales team", "Demo"],
                    "pain_points": ["Complex pricing", "Long implementation"],
                    "decision_factors": ["ROI", "Support quality"]
                }
            },
            "market_drivers": {
                "growth_drivers": [
                    {
                        "driver": "Digital transformation",
                        "impact": "High",
                        "timeline": "2024-2026",
                        "evidence": ["Industry reports", "Customer surveys"]
                    }
                ],
                "trends": [
                    {
                        "trend": "AI integration",
                        "category": "Technology",
                        "stage": "Growth",
                        "impact": "High"
                    }
                ],
                "challenges": [
                    {
                        "challenge": "Data security",
                        "severity": "High",
                        "solutions": ["Enhanced encryption", "Regular audits"]
                    }
                ]
            },
            "opportunities": [
                {
                    "opportunity": "AI-powered solutions",
                    "size": 50000000,
                    "timeline": "12 months",
                    "requirements": ["AI expertise", "Data infrastructure"],
                    "risks": ["Technology adoption", "Competition"],
                    "roi": {
                        "value": 200,
                        "timeline": "24 months",
                        "assumptions": ["Market growth continues", "Tech adoption"]
                    }
                }
            ],
            "recommendations": [
                {
                    "recommendation": "Expand AI capabilities",
                    "priority": "High",
                    "rationale": "Growing market demand",
                    "actions": ["Hire AI team", "Develop roadmap"],
                    "resources": ["Budget", "Personnel"],
                    "timeline": "12 months",
                    "success_metrics": ["Revenue growth", "Market share"]
                }
            ],
            "metadata": {
                "created_at": "2024-04-03T12:34:56Z",
                "created_by": "analyst-456",
                "last_updated": "2024-04-03T12:34:56Z",
                "version": "1.0",
                "status": "final",
                "methodology": {
                    "approach": "Mixed methods",
                    "data_sources": ["Market research", "Interviews"],
                    "limitations": ["Limited data availability"]
                },
                "contributors": [
                    {
                        "name": "John Doe",
                        "role": "Lead Analyst",
                        "expertise": "SaaS Markets"
                    }
                ],
                "tags": ["saas", "technology", "market-analysis"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="market_analysis",
            version="1.0",
            description="Schema for representing market analysis and insights",
            schema={
                "type": "object",
                "required": ["timestamp", "analysis_id", "organization_id", "market_overview", "market_size"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the analysis was created"
                    },
                    "analysis_id": {
                        "type": "string",
                        "description": "Unique identifier for the market analysis"
                    },
                    "organization_id": {
                        "type": "string",
                        "description": "Identifier of the organization"
                    },
                    "market_overview": {
                        "type": "object",
                        "required": ["title", "description", "scope", "time_period"],
                        "properties": {
                            "title": {
                                "type": "string",
                                "description": "Analysis title"
                            },
                            "description": {
                                "type": "string",
                                "description": "Analysis description"
                            },
                            "scope": {
                                "type": "string",
                                "description": "Analysis scope"
                            },
                            "time_period": {
                                "type": "object",
                                "required": ["start_date", "end_date"],
                                "properties": {
                                    "start_date": {
                                        "type": "string",
                                        "format": "date",
                                        "description": "Start date of analysis"
                                    },
                                    "end_date": {
                                        "type": "string",
                                        "format": "date",
                                        "description": "End date of analysis"
                                    }
                                }
                            },
                            "geography": {
                                "type": "object",
                                "properties": {
                                    "regions": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Covered regions"
                                    },
                                    "countries": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Covered countries"
                                    },
                                    "markets": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Specific markets"
                                    }
                                }
                            },
                            "industry": {
                                "type": "object",
                                "properties": {
                                    "sector": {
                                        "type": "string",
                                        "description": "Industry sector"
                                    },
                                    "subsectors": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Industry subsectors"
                                    },
                                    "verticals": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Industry verticals"
                                    }
                                }
                            }
                        }
                    },
                    "market_size": {
                        "type": "object",
                        "required": ["total_market"],
                        "properties": {
                            "total_market": {
                                "type": "object",
                                "required": ["value", "currency", "year"],
                                "properties": {
                                    "value": {
                                        "type": "number",
                                        "description": "Market value"
                                    },
                                    "currency": {
                                        "type": "string",
                                        "description": "Currency"
                                    },
                                    "year": {
                                        "type": "integer",
                                        "description": "Reference year"
                                    },
                                    "cagr": {
                                        "type": "number",
                                        "description": "Compound annual growth rate"
                                    }
                                }
                            },
                            "segmentation": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["segment", "value", "share"],
                                    "properties": {
                                        "segment": {
                                            "type": "string",
                                            "description": "Segment name"
                                        },
                                        "value": {
                                            "type": "number",
                                            "description": "Segment value"
                                        },
                                        "share": {
                                            "type": "number",
                                            "description": "Market share percentage"
                                        },
                                        "growth_rate": {
                                            "type": "number",
                                            "description": "Segment growth rate"
                                        }
                                    }
                                }
                            },
                            "forecasts": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["year", "value"],
                                    "properties": {
                                        "year": {
                                            "type": "integer",
                                            "description": "Forecast year"
                                        },
                                        "value": {
                                            "type": "number",
                                            "description": "Projected value"
                                        },
                                        "growth": {
                                            "type": "number",
                                            "description": "Expected growth"
                                        },
                                        "assumptions": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Forecast assumptions"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "competitive_landscape": {
                        "type": "object",
                        "properties": {
                            "competitors": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "market_share"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Competitor name"
                                        },
                                        "market_share": {
                                            "type": "number",
                                            "description": "Market share percentage"
                                        },
                                        "strengths": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Key strengths"
                                        },
                                        "weaknesses": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Key weaknesses"
                                        },
                                        "strategy": {
                                            "type": "string",
                                            "description": "Competitive strategy"
                                        },
                                        "positioning": {
                                            "type": "string",
                                            "description": "Market positioning"
                                        }
                                    }
                                }
                            },
                            "market_concentration": {
                                "type": "object",
                                "properties": {
                                    "type": {
                                        "type": "string",
                                        "enum": ["Perfect Competition", "Monopolistic Competition", "Oligopoly", "Monopoly"],
                                        "description": "Concentration type"
                                    },
                                    "hhi": {
                                        "type": "number",
                                        "description": "Herfindahl-Hirschman Index"
                                    },
                                    "cr4": {
                                        "type": "number",
                                        "description": "Four-firm concentration ratio"
                                    }
                                }
                            },
                            "entry_barriers": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["barrier", "impact"],
                                    "properties": {
                                        "barrier": {
                                            "type": "string",
                                            "description": "Barrier description"
                                        },
                                        "impact": {
                                            "type": "string",
                                            "enum": ["Low", "Medium", "High"],
                                            "description": "Impact level"
                                        },
                                        "mitigation": {
                                            "type": "string",
                                            "description": "Possible mitigation"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "customer_analysis": {
                        "type": "object",
                        "properties": {
                            "segments": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "description", "size"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Segment name"
                                        },
                                        "description": {
                                            "type": "string",
                                            "description": "Segment description"
                                        },
                                        "size": {
                                            "type": "number",
                                            "description": "Segment size"
                                        },
                                        "demographics": {
                                            "type": "object",
                                            "description": "Demographic characteristics"
                                        },
                                        "needs": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Customer needs"
                                        },
                                        "behavior": {
                                            "type": "object",
                                            "description": "Buying behavior"
                                        },
                                        "value": {
                                            "type": "number",
                                            "description": "Segment value"
                                        }
                                    }
                                }
                            },
                            "preferences": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["attribute", "importance"],
                                    "properties": {
                                        "attribute": {
                                            "type": "string",
                                            "description": "Product/service attribute"
                                        },
                                        "importance": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 10,
                                            "description": "Importance rating"
                                        },
                                        "trends": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Preference trends"
                                        }
                                    }
                                }
                            },
                            "journey": {
                                "type": "object",
                                "properties": {
                                    "touchpoints": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Customer touchpoints"
                                    },
                                    "pain_points": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Customer pain points"
                                    },
                                    "decision_factors": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Purchase decision factors"
                                    }
                                }
                            }
                        }
                    },
                    "market_drivers": {
                        "type": "object",
                        "properties": {
                            "growth_drivers": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["driver", "impact"],
                                    "properties": {
                                        "driver": {
                                            "type": "string",
                                            "description": "Driver description"
                                        },
                                        "impact": {
                                            "type": "string",
                                            "enum": ["Low", "Medium", "High"],
                                            "description": "Impact level"
                                        },
                                        "timeline": {
                                            "type": "string",
                                            "description": "Impact timeline"
                                        },
                                        "evidence": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Supporting evidence"
                                        }
                                    }
                                }
                            },
                            "trends": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["trend", "category", "impact"],
                                    "properties": {
                                        "trend": {
                                            "type": "string",
                                            "description": "Trend description"
                                        },
                                        "category": {
                                            "type": "string",
                                            "description": "Trend category"
                                        },
                                        "stage": {
                                            "type": "string",
                                            "enum": ["Emerging", "Growth", "Mature", "Declining"],
                                            "description": "Trend lifecycle stage"
                                        },
                                        "impact": {
                                            "type": "string",
                                            "enum": ["Low", "Medium", "High"],
                                            "description": "Expected impact"
                                        }
                                    }
                                }
                            },
                            "challenges": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["challenge", "severity"],
                                    "properties": {
                                        "challenge": {
                                            "type": "string",
                                            "description": "Challenge description"
                                        },
                                        "severity": {
                                            "type": "string",
                                            "enum": ["Low", "Medium", "High"],
                                            "description": "Challenge severity"
                                        },
                                        "solutions": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Potential solutions"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "opportunities": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["opportunity", "size", "timeline"],
                            "properties": {
                                "opportunity": {
                                    "type": "string",
                                    "description": "Opportunity description"
                                },
                                "size": {
                                    "type": "number",
                                    "description": "Opportunity size"
                                },
                                "timeline": {
                                    "type": "string",
                                    "description": "Implementation timeline"
                                },
                                "requirements": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Requirements"
                                },
                                "risks": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Associated risks"
                                },
                                "roi": {
                                    "type": "object",
                                    "properties": {
                                        "value": {
                                            "type": "number",
                                            "description": "ROI value"
                                        },
                                        "timeline": {
                                            "type": "string",
                                            "description": "ROI timeline"
                                        },
                                        "assumptions": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "ROI assumptions"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "recommendations": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "required": ["recommendation", "priority", "rationale"],
                            "properties": {
                                "recommendation": {
                                    "type": "string",
                                    "description": "Recommendation description"
                                },
                                "priority": {
                                    "type": "string",
                                    "enum": ["Low", "Medium", "High"],
                                    "description": "Implementation priority"
                                },
                                "rationale": {
                                    "type": "string",
                                    "description": "Recommendation rationale"
                                },
                                "actions": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Required actions"
                                },
                                "resources": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Required resources"
                                },
                                "timeline": {
                                    "type": "string",
                                    "description": "Implementation timeline"
                                },
                                "success_metrics": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "description": "Success metrics"
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Analysis creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Analysis version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "in_review", "final", "archived"],
                                "description": "Analysis status"
                            },
                            "methodology": {
                                "type": "object",
                                "properties": {
                                    "approach": {
                                        "type": "string",
                                        "description": "Research approach"
                                    },
                                    "data_sources": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Data sources"
                                    },
                                    "limitations": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Research limitations"
                                    }
                                }
                            },
                            "contributors": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "role"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Contributor name"
                                        },
                                        "role": {
                                            "type": "string",
                                            "description": "Contribution role"
                                        },
                                        "expertise": {
                                            "type": "string",
                                            "description": "Area of expertise"
                                        }
                                    }
                                }
                            },
                            "tags": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Relevant tags"
                            }
                        }
                    }
                }
            }
        ) 