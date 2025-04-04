"""
ProblemSolving Schema

This schema defines the structure for representing systematic problem-solving processes.
It's particularly useful for:
- Complex problem decomposition
- Solution strategy development
- Progress tracking
- Collaborative problem solving
- Solution evaluation and refinement

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.cognitive.problem_solving import ProblemSolvingSchema

# Create a problem-solving process
signal = Signal(
    schema=ProblemSolvingSchema,
    payload={
        "problem_statement": {
            "title": "High Customer Churn Rate",
            "description": "Monthly customer churn rate has increased from 2% to 5% over the last quarter",
            "domain": "customer_retention",
            "urgency": 0.8,
            "impact_areas": ["revenue", "customer_satisfaction", "market_reputation"]
        },
        "context": {
            "background": "SaaS product with 50,000 active users",
            "constraints": [
                "Limited development resources",
                "Must maintain service quality",
                "Budget constraints for customer incentives"
            ],
            "stakeholders": ["customer_success", "product", "sales", "engineering"]
        },
        "problem_analysis": {
            "root_causes": [
                {
                    "cause": "Poor onboarding experience",
                    "evidence": [
                        "60% drop in feature adoption after first week",
                        "High support ticket volume from new users"
                    ],
                    "confidence": 0.85
                },
                {
                    "cause": "Missing key features",
                    "evidence": [
                        "Competitor analysis shows gap in functionality",
                        "Feature requests in customer feedback"
                    ],
                    "confidence": 0.75
                }
            ],
            "contributing_factors": [
                {
                    "factor": "Market competition",
                    "impact_score": 0.6,
                    "description": "New competitors with lower pricing"
                },
                {
                    "factor": "User experience",
                    "impact_score": 0.8,
                    "description": "Complex workflow for common tasks"
                }
            ]
        },
        "solution_approach": {
            "methodology": "Agile iterative improvement",
            "phases": [
                {
                    "name": "Immediate Mitigation",
                    "duration_days": 30,
                    "objectives": [
                        "Improve onboarding flow",
                        "Enhance customer support response"
                    ],
                    "success_criteria": [
                        "Reduce new user churn by 20%",
                        "Increase feature adoption by 25%"
                    ]
                },
                {
                    "name": "Long-term Solutions",
                    "duration_days": 90,
                    "objectives": [
                        "Develop missing features",
                        "Streamline user workflows"
                    ],
                    "success_criteria": [
                        "Return churn rate to 2%",
                        "Achieve 85% feature satisfaction"
                    ]
                }
            ]
        },
        "proposed_solutions": [
            {
                "title": "Enhanced Onboarding Program",
                "description": "Implement interactive tutorials and personalized onboarding",
                "implementation_complexity": 0.6,
                "expected_impact": 0.8,
                "resources_required": {
                    "development_hours": 240,
                    "design_hours": 80,
                    "training_hours": 40
                },
                "risks": [
                    {
                        "description": "Initial user resistance to new flow",
                        "severity": 0.4,
                        "mitigation": "A/B testing and gradual rollout"
                    }
                ]
            },
            {
                "title": "Feature Enhancement Initiative",
                "description": "Develop and launch top requested features",
                "implementation_complexity": 0.8,
                "expected_impact": 0.9,
                "resources_required": {
                    "development_hours": 600,
                    "design_hours": 160,
                    "testing_hours": 120
                },
                "risks": [
                    {
                        "description": "Delayed delivery impact",
                        "severity": 0.7,
                        "mitigation": "Phased release approach"
                    }
                ]
            }
        ],
        "progress_tracking": {
            "current_phase": "Immediate Mitigation",
            "completion_percentage": 35,
            "metrics": {
                "churn_rate_current": 4.2,
                "feature_adoption_improvement": 15,
                "customer_satisfaction_delta": 0.3
            },
            "blockers": [
                {
                    "description": "Resource allocation for development",
                    "severity": 0.6,
                    "status": "in_progress",
                    "resolution_plan": "Temporary team reallocation"
                }
            ]
        },
        "learnings": [
            {
                "insight": "Early user engagement crucial for retention",
                "source": "Onboarding analysis",
                "applicability": "High",
                "action_items": [
                    "Implement engagement tracking",
                    "Develop early warning system"
                ]
            }
        ],
        "next_steps": [
            {
                "action": "Complete onboarding redesign",
                "priority": 0.9,
                "deadline": "2024-04-15",
                "owner": "product_team"
            },
            {
                "action": "Begin feature development sprint",
                "priority": 0.8,
                "deadline": "2024-04-30",
                "owner": "engineering_team"
            }
        ]
    }
)
```

Schema Structure:
- problem_statement: Clear definition of the problem
- context: Background information and constraints
- problem_analysis: Root causes and contributing factors
- solution_approach: Methodology and phases
- proposed_solutions: Detailed solution proposals
- progress_tracking: Implementation progress
- learnings: Insights gained during the process
- next_steps: Upcoming actions and responsibilities

The schema enforces:
- Required problem components
- Valid confidence and impact scores
- Structured solution proposals
- Clear success criteria
- Progress tracking metrics
"""

from lux_sdk.signals import SignalSchema

SCHEMA = {
    "type": "object",
    "properties": {
        "problem_statement": {
            "type": "object",
            "properties": {
                "title": {
                    "type": "string",
                    "description": "Brief title of the problem"
                },
                "description": {
                    "type": "string",
                    "description": "Detailed description of the problem"
                },
                "domain": {
                    "type": "string",
                    "description": "Problem domain or category"
                },
                "urgency": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Problem urgency score"
                },
                "impact_areas": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Areas affected by the problem"
                }
            },
            "required": ["title", "description", "urgency"],
            "additionalProperties": False
        },
        "context": {
            "type": "object",
            "properties": {
                "background": {
                    "type": "string",
                    "description": "Background information"
                },
                "constraints": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Limiting factors or requirements"
                },
                "stakeholders": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Involved parties or teams"
                }
            },
            "required": ["background"],
            "additionalProperties": False
        },
        "problem_analysis": {
            "type": "object",
            "properties": {
                "root_causes": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "cause": {
                                "type": "string",
                                "description": "Root cause description"
                            },
                            "evidence": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Supporting evidence"
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Confidence in this cause"
                            }
                        },
                        "required": ["cause", "confidence"],
                        "additionalProperties": False
                    }
                },
                "contributing_factors": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "factor": {
                                "type": "string",
                                "description": "Contributing factor"
                            },
                            "impact_score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Impact of this factor"
                            },
                            "description": {
                                "type": "string",
                                "description": "Detailed description"
                            }
                        },
                        "required": ["factor", "impact_score"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["root_causes"],
            "additionalProperties": False
        },
        "solution_approach": {
            "type": "object",
            "properties": {
                "methodology": {
                    "type": "string",
                    "description": "Problem-solving methodology"
                },
                "phases": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Phase name"
                            },
                            "duration_days": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Expected duration in days"
                            },
                            "objectives": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Phase objectives"
                            },
                            "success_criteria": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Measurable success criteria"
                            }
                        },
                        "required": ["name", "objectives", "success_criteria"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["methodology", "phases"],
            "additionalProperties": False
        },
        "proposed_solutions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "Solution title"
                    },
                    "description": {
                        "type": "string",
                        "description": "Detailed solution description"
                    },
                    "implementation_complexity": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Complexity score"
                    },
                    "expected_impact": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Expected impact score"
                    },
                    "resources_required": {
                        "type": "object",
                        "description": "Required resources"
                    },
                    "risks": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "description": {
                                    "type": "string",
                                    "description": "Risk description"
                                },
                                "severity": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Risk severity"
                                },
                                "mitigation": {
                                    "type": "string",
                                    "description": "Mitigation strategy"
                                }
                            },
                            "required": ["description", "severity"],
                            "additionalProperties": False
                        }
                    }
                },
                "required": ["title", "description", "implementation_complexity", "expected_impact"],
                "additionalProperties": False
            }
        },
        "progress_tracking": {
            "type": "object",
            "properties": {
                "current_phase": {
                    "type": "string",
                    "description": "Current implementation phase"
                },
                "completion_percentage": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 100,
                    "description": "Overall completion percentage"
                },
                "metrics": {
                    "type": "object",
                    "description": "Current metrics and KPIs"
                },
                "blockers": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "description": {
                                "type": "string",
                                "description": "Blocker description"
                            },
                            "severity": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Blocker severity"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["identified", "in_progress", "resolved"],
                                "description": "Current status"
                            },
                            "resolution_plan": {
                                "type": "string",
                                "description": "Plan to resolve the blocker"
                            }
                        },
                        "required": ["description", "severity", "status"],
                        "additionalProperties": False
                    }
                }
            },
            "required": ["current_phase", "completion_percentage"],
            "additionalProperties": False
        },
        "learnings": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "insight": {
                        "type": "string",
                        "description": "Learning or insight"
                    },
                    "source": {
                        "type": "string",
                        "description": "Source of the learning"
                    },
                    "applicability": {
                        "type": "string",
                        "description": "Where this learning applies"
                    },
                    "action_items": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Actions based on this learning"
                    }
                },
                "required": ["insight"],
                "additionalProperties": False
            }
        },
        "next_steps": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "description": "Next action to take"
                    },
                    "priority": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Action priority"
                    },
                    "deadline": {
                        "type": "string",
                        "format": "date",
                        "description": "Action deadline"
                    },
                    "owner": {
                        "type": "string",
                        "description": "Responsible party"
                    }
                },
                "required": ["action", "priority"],
                "additionalProperties": False
            }
        }
    },
    "required": [
        "problem_statement",
        "context",
        "problem_analysis",
        "solution_approach",
        "proposed_solutions"
    ],
    "additionalProperties": False
}

ProblemSolvingSchema = SignalSchema(
    name="lux.cognitive.problem_solving",
    version="1.0",
    description="Schema for representing systematic problem-solving processes",
    schema=SCHEMA
) 