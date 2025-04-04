"""
Schema for representing project proposals and their components.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ProjectProposalSchema(SignalSchema):
    """Schema for representing comprehensive project proposals.
    
    This schema defines the structure for project proposals, including executive summary,
    business case, implementation plan, financial analysis, and risk assessment.
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "proposal_id": "pp-123456",
            "organization_id": "org-789",
            "executive_summary": {
                "title": "AI-Powered Customer Service Platform",
                "vision": "Transform customer service through AI automation",
                "objectives": [
                    "Reduce response time by 50%",
                    "Increase customer satisfaction by 30%"
                ],
                "value_proposition": "24/7 intelligent customer support",
                "key_stakeholders": ["Customer Service", "IT", "Sales"]
            },
            "business_case": {
                "problem_statement": "Long customer service response times",
                "market_analysis": {
                    "target_market": "Enterprise B2B companies",
                    "market_size": 5000000000,
                    "competitors": [
                        {
                            "name": "ServiceAI",
                            "strengths": ["Market leader", "Strong AI"],
                            "weaknesses": ["High cost", "Complex setup"]
                        }
                    ]
                },
                "benefits": [
                    {
                        "description": "Reduced operational costs",
                        "type": "financial",
                        "metrics": ["Cost per ticket", "Resolution time"]
                    }
                ]
            },
            "implementation_plan": {
                "phases": [
                    {
                        "name": "Phase 1: Setup",
                        "description": "Initial platform setup",
                        "start_date": "2024-05-01",
                        "end_date": "2024-06-30",
                        "deliverables": ["AI model", "API integration"],
                        "milestones": [
                            {
                                "name": "Platform Launch",
                                "date": "2024-06-30",
                                "criteria": ["95% uptime", "API tests passed"]
                            }
                        ]
                    }
                ],
                "resources": {
                    "team": [
                        {
                            "role": "AI Engineer",
                            "skills": ["Python", "ML", "APIs"],
                            "allocation": 100
                        }
                    ],
                    "technology": ["Cloud servers", "ML frameworks"],
                    "facilities": ["Development lab"]
                }
            },
            "financial_analysis": {
                "costs": {
                    "capital": 500000,
                    "operational": 100000,
                    "breakdown": [
                        {
                            "category": "Infrastructure",
                            "amount": 200000,
                            "frequency": "one-time"
                        }
                    ]
                },
                "revenue": {
                    "streams": [
                        {
                            "source": "Subscriptions",
                            "amount": 1000000,
                            "timeline": "Year 1"
                        }
                    ],
                    "assumptions": ["80% customer retention"]
                },
                "roi_analysis": {
                    "roi_percentage": 150,
                    "payback_period": "18 months",
                    "npv": 2000000,
                    "irr": 35
                }
            },
            "risk_assessment": {
                "risks": [
                    {
                        "description": "Technical integration challenges",
                        "category": "Technical",
                        "probability": 0.3,
                        "impact": 4,
                        "mitigation": "Early testing and POC"
                    }
                ],
                "dependencies": [
                    {
                        "description": "Cloud infrastructure",
                        "type": "Technical",
                        "criticality": "High"
                    }
                ]
            },
            "metadata": {
                "created_at": "2024-04-03T12:34:56Z",
                "created_by": "user-456",
                "last_updated": "2024-04-03T12:34:56Z",
                "version": "1.0",
                "status": "draft",
                "reviewers": ["manager-123", "tech-lead-456"],
                "approval_chain": [
                    {
                        "role": "Technical Lead",
                        "status": "pending",
                        "comments": null
                    }
                ],
                "tags": ["ai", "customer-service", "automation"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="project_proposal",
            version="1.0",
            description="Schema for representing project proposals and their components",
            schema={
                "type": "object",
                "required": ["timestamp", "proposal_id", "organization_id", "executive_summary", "business_case", "implementation_plan"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of the proposal"
                    },
                    "proposal_id": {
                        "type": "string",
                        "description": "Unique identifier for the proposal"
                    },
                    "organization_id": {
                        "type": "string",
                        "description": "Identifier of the proposing organization"
                    },
                    "executive_summary": {
                        "type": "object",
                        "required": ["title", "vision", "objectives"],
                        "properties": {
                            "title": {
                                "type": "string",
                                "description": "Project title"
                            },
                            "vision": {
                                "type": "string",
                                "description": "Project vision statement"
                            },
                            "objectives": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Key project objectives"
                            },
                            "value_proposition": {
                                "type": "string",
                                "description": "Core value proposition"
                            },
                            "key_stakeholders": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Primary stakeholders"
                            }
                        }
                    },
                    "business_case": {
                        "type": "object",
                        "required": ["problem_statement"],
                        "properties": {
                            "problem_statement": {
                                "type": "string",
                                "description": "Problem being addressed"
                            },
                            "market_analysis": {
                                "type": "object",
                                "properties": {
                                    "target_market": {
                                        "type": "string",
                                        "description": "Target market description"
                                    },
                                    "market_size": {
                                        "type": "number",
                                        "description": "Estimated market size"
                                    },
                                    "competitors": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "required": ["name"],
                                            "properties": {
                                                "name": {
                                                    "type": "string",
                                                    "description": "Competitor name"
                                                },
                                                "strengths": {
                                                    "type": "array",
                                                    "items": {"type": "string"},
                                                    "description": "Competitive strengths"
                                                },
                                                "weaknesses": {
                                                    "type": "array",
                                                    "items": {"type": "string"},
                                                    "description": "Competitive weaknesses"
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "benefits": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["description", "type"],
                                    "properties": {
                                        "description": {
                                            "type": "string",
                                            "description": "Benefit description"
                                        },
                                        "type": {
                                            "type": "string",
                                            "enum": ["financial", "operational", "strategic"],
                                            "description": "Benefit type"
                                        },
                                        "metrics": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Success metrics"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "implementation_plan": {
                        "type": "object",
                        "required": ["phases"],
                        "properties": {
                            "phases": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "start_date", "end_date"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Phase name"
                                        },
                                        "description": {
                                            "type": "string",
                                            "description": "Phase description"
                                        },
                                        "start_date": {
                                            "type": "string",
                                            "format": "date",
                                            "description": "Planned start date"
                                        },
                                        "end_date": {
                                            "type": "string",
                                            "format": "date",
                                            "description": "Planned end date"
                                        },
                                        "deliverables": {
                                            "type": "array",
                                            "items": {"type": "string"},
                                            "description": "Phase deliverables"
                                        },
                                        "milestones": {
                                            "type": "array",
                                            "items": {
                                                "type": "object",
                                                "required": ["name", "date"],
                                                "properties": {
                                                    "name": {
                                                        "type": "string",
                                                        "description": "Milestone name"
                                                    },
                                                    "date": {
                                                        "type": "string",
                                                        "format": "date",
                                                        "description": "Target date"
                                                    },
                                                    "criteria": {
                                                        "type": "array",
                                                        "items": {"type": "string"},
                                                        "description": "Success criteria"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "resources": {
                                "type": "object",
                                "properties": {
                                    "team": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "required": ["role", "allocation"],
                                            "properties": {
                                                "role": {
                                                    "type": "string",
                                                    "description": "Role name"
                                                },
                                                "skills": {
                                                    "type": "array",
                                                    "items": {"type": "string"},
                                                    "description": "Required skills"
                                                },
                                                "allocation": {
                                                    "type": "number",
                                                    "minimum": 0,
                                                    "maximum": 100,
                                                    "description": "Time allocation percentage"
                                                }
                                            }
                                        }
                                    },
                                    "technology": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Technology requirements"
                                    },
                                    "facilities": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Facility requirements"
                                    }
                                }
                            }
                        }
                    },
                    "financial_analysis": {
                        "type": "object",
                        "properties": {
                            "costs": {
                                "type": "object",
                                "required": ["capital", "operational"],
                                "properties": {
                                    "capital": {
                                        "type": "number",
                                        "description": "Capital expenditure"
                                    },
                                    "operational": {
                                        "type": "number",
                                        "description": "Operational expenditure"
                                    },
                                    "breakdown": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "required": ["category", "amount"],
                                            "properties": {
                                                "category": {
                                                    "type": "string",
                                                    "description": "Cost category"
                                                },
                                                "amount": {
                                                    "type": "number",
                                                    "description": "Cost amount"
                                                },
                                                "frequency": {
                                                    "type": "string",
                                                    "enum": ["one-time", "monthly", "quarterly", "annual"],
                                                    "description": "Payment frequency"
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "revenue": {
                                "type": "object",
                                "properties": {
                                    "streams": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "required": ["source", "amount"],
                                            "properties": {
                                                "source": {
                                                    "type": "string",
                                                    "description": "Revenue source"
                                                },
                                                "amount": {
                                                    "type": "number",
                                                    "description": "Projected amount"
                                                },
                                                "timeline": {
                                                    "type": "string",
                                                    "description": "Revenue timeline"
                                                }
                                            }
                                        }
                                    },
                                    "assumptions": {
                                        "type": "array",
                                        "items": {"type": "string"},
                                        "description": "Revenue assumptions"
                                    }
                                }
                            },
                            "roi_analysis": {
                                "type": "object",
                                "properties": {
                                    "roi_percentage": {
                                        "type": "number",
                                        "description": "Expected ROI percentage"
                                    },
                                    "payback_period": {
                                        "type": "string",
                                        "description": "Expected payback period"
                                    },
                                    "npv": {
                                        "type": "number",
                                        "description": "Net present value"
                                    },
                                    "irr": {
                                        "type": "number",
                                        "description": "Internal rate of return"
                                    }
                                }
                            }
                        }
                    },
                    "risk_assessment": {
                        "type": "object",
                        "properties": {
                            "risks": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["description", "category", "probability", "impact"],
                                    "properties": {
                                        "description": {
                                            "type": "string",
                                            "description": "Risk description"
                                        },
                                        "category": {
                                            "type": "string",
                                            "enum": ["Technical", "Financial", "Operational", "Strategic", "Compliance"],
                                            "description": "Risk category"
                                        },
                                        "probability": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 1,
                                            "description": "Probability (0-1)"
                                        },
                                        "impact": {
                                            "type": "number",
                                            "minimum": 1,
                                            "maximum": 5,
                                            "description": "Impact severity (1-5)"
                                        },
                                        "mitigation": {
                                            "type": "string",
                                            "description": "Mitigation strategy"
                                        }
                                    }
                                }
                            },
                            "dependencies": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["description", "type", "criticality"],
                                    "properties": {
                                        "description": {
                                            "type": "string",
                                            "description": "Dependency description"
                                        },
                                        "type": {
                                            "type": "string",
                                            "enum": ["Technical", "Resource", "Business", "External"],
                                            "description": "Dependency type"
                                        },
                                        "criticality": {
                                            "type": "string",
                                            "enum": ["Low", "Medium", "High"],
                                            "description": "Dependency criticality"
                                        }
                                    }
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
                                "description": "Proposal creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Proposal version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "submitted", "approved", "rejected"],
                                "description": "Status"
                            },
                            "reviewers": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Assigned reviewers"
                            },
                            "approval_chain": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["role", "status"],
                                    "properties": {
                                        "role": {
                                            "type": "string",
                                            "description": "Approver role"
                                        },
                                        "status": {
                                            "type": "string",
                                            "enum": ["pending", "approved", "rejected"],
                                            "description": "Approval status"
                                        },
                                        "comments": {
                                            "type": "string",
                                            "description": "Approval comments"
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