"""
Schema for financial reporting and analysis.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class FinancialReportSchema(SignalSchema):
    """Schema for representing financial reports and analysis.
    
    This schema defines the structure for comprehensive financial reports,
    including income statements, balance sheets, cash flow statements,
    financial metrics, and analysis.
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "report_id": "fr-123456",
            "organization_id": "org-789",
            "report_info": {
                "title": "Q1 2024 Financial Report",
                "type": "quarterly",
                "period": {
                    "start_date": "2024-01-01",
                    "end_date": "2024-03-31",
                    "fiscal_year": "2024"
                },
                "currency": "USD"
            },
            "income_statement": {
                "revenue": {
                    "total": 1000000.00,
                    "breakdown": [
                        {
                            "source": "Product Sales",
                            "amount": 800000.00,
                            "percentage": 80.0
                        },
                        {
                            "source": "Services",
                            "amount": 200000.00,
                            "percentage": 20.0
                        }
                    ]
                },
                "expenses": {
                    "total": 750000.00,
                    "categories": [
                        {
                            "category": "Cost of Goods Sold",
                            "amount": 400000.00,
                            "percentage": 53.3
                        },
                        {
                            "category": "Operating Expenses",
                            "amount": 350000.00,
                            "percentage": 46.7
                        }
                    ]
                },
                "net_income": 250000.00
            },
            "balance_sheet": {
                "assets": {
                    "total": 2000000.00,
                    "current_assets": {
                        "cash": 500000.00,
                        "accounts_receivable": 300000.00,
                        "inventory": 200000.00
                    },
                    "non_current_assets": {
                        "property_and_equipment": 1000000.00
                    }
                },
                "liabilities": {
                    "total": 1000000.00,
                    "current_liabilities": {
                        "accounts_payable": 200000.00,
                        "short_term_debt": 300000.00
                    },
                    "non_current_liabilities": {
                        "long_term_debt": 500000.00
                    }
                },
                "equity": {
                    "total": 1000000.00,
                    "components": {
                        "common_stock": 500000.00,
                        "retained_earnings": 500000.00
                    }
                }
            },
            "cash_flow": {
                "operating_activities": {
                    "net_cash": 300000.00
                },
                "investing_activities": {
                    "net_cash": -100000.00
                },
                "financing_activities": {
                    "net_cash": -50000.00
                },
                "net_change": 150000.00
            },
            "financial_metrics": {
                "profitability": {
                    "gross_margin": 0.60,
                    "operating_margin": 0.25,
                    "net_margin": 0.25,
                    "roi": 0.125
                },
                "liquidity": {
                    "current_ratio": 2.0,
                    "quick_ratio": 1.6,
                    "cash_ratio": 1.0
                },
                "efficiency": {
                    "asset_turnover": 0.5,
                    "inventory_turnover": 4.0,
                    "receivables_turnover": 6.0
                }
            },
            "analysis": {
                "summary": "Strong quarterly performance with improved margins",
                "key_findings": [
                    "Revenue growth of 15% YoY",
                    "Improved operating efficiency"
                ],
                "trends": [
                    "Increasing service revenue",
                    "Stable gross margins"
                ],
                "recommendations": [
                    "Invest in service delivery capacity",
                    "Optimize working capital"
                ]
            },
            "metadata": {
                "created_at": "2024-04-03T12:34:56Z",
                "updated_at": "2024-04-03T12:34:56Z",
                "prepared_by": "fin-456",
                "reviewed_by": "fin-789",
                "status": "final",
                "version": "1.0",
                "tags": ["quarterly", "consolidated"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="financial_report",
            version="1.0",
            description="Schema for representing financial reports and analysis",
            schema={
                "type": "object",
                "required": ["timestamp", "report_id", "organization_id", "report_info", "income_statement", "balance_sheet"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the report was created"
                    },
                    "report_id": {
                        "type": "string",
                        "description": "Unique identifier for the financial report"
                    },
                    "organization_id": {
                        "type": "string",
                        "description": "Identifier of the organization"
                    },
                    "report_info": {
                        "type": "object",
                        "required": ["title", "type", "period", "currency"],
                        "properties": {
                            "title": {
                                "type": "string",
                                "description": "Title of the report"
                            },
                            "type": {
                                "type": "string",
                                "description": "Type of financial report",
                                "enum": ["annual", "quarterly", "monthly", "special"]
                            },
                            "period": {
                                "type": "object",
                                "required": ["start_date", "end_date"],
                                "properties": {
                                    "start_date": {
                                        "type": "string",
                                        "format": "date",
                                        "description": "Start date of the period"
                                    },
                                    "end_date": {
                                        "type": "string",
                                        "format": "date",
                                        "description": "End date of the period"
                                    },
                                    "fiscal_year": {
                                        "type": "string",
                                        "description": "Fiscal year"
                                    }
                                }
                            },
                            "currency": {
                                "type": "string",
                                "description": "Primary currency used"
                            }
                        }
                    },
                    "income_statement": {
                        "type": "object",
                        "required": ["revenue", "expenses", "net_income"],
                        "properties": {
                            "revenue": {
                                "type": "object",
                                "required": ["total"],
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "description": "Total revenue"
                                    },
                                    "breakdown": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "required": ["source", "amount", "percentage"],
                                            "properties": {
                                                "source": {
                                                    "type": "string",
                                                    "description": "Revenue source"
                                                },
                                                "amount": {
                                                    "type": "number",
                                                    "description": "Amount"
                                                },
                                                "percentage": {
                                                    "type": "number",
                                                    "description": "Percentage of total"
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "expenses": {
                                "type": "object",
                                "required": ["total"],
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "description": "Total expenses"
                                    },
                                    "categories": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "required": ["category", "amount", "percentage"],
                                            "properties": {
                                                "category": {
                                                    "type": "string",
                                                    "description": "Expense category"
                                                },
                                                "amount": {
                                                    "type": "number",
                                                    "description": "Amount"
                                                },
                                                "percentage": {
                                                    "type": "number",
                                                    "description": "Percentage of total"
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "net_income": {
                                "type": "number",
                                "description": "Net income for the period"
                            }
                        }
                    },
                    "balance_sheet": {
                        "type": "object",
                        "required": ["assets", "liabilities", "equity"],
                        "properties": {
                            "assets": {
                                "type": "object",
                                "required": ["total"],
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "description": "Total assets"
                                    },
                                    "current_assets": {
                                        "type": "object",
                                        "description": "Current assets breakdown"
                                    },
                                    "non_current_assets": {
                                        "type": "object",
                                        "description": "Non-current assets breakdown"
                                    }
                                }
                            },
                            "liabilities": {
                                "type": "object",
                                "required": ["total"],
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "description": "Total liabilities"
                                    },
                                    "current_liabilities": {
                                        "type": "object",
                                        "description": "Current liabilities breakdown"
                                    },
                                    "non_current_liabilities": {
                                        "type": "object",
                                        "description": "Non-current liabilities breakdown"
                                    }
                                }
                            },
                            "equity": {
                                "type": "object",
                                "required": ["total"],
                                "properties": {
                                    "total": {
                                        "type": "number",
                                        "description": "Total equity"
                                    },
                                    "components": {
                                        "type": "object",
                                        "description": "Equity components breakdown"
                                    }
                                }
                            }
                        }
                    },
                    "cash_flow": {
                        "type": "object",
                        "properties": {
                            "operating_activities": {
                                "type": "object",
                                "description": "Operating cash flow details"
                            },
                            "investing_activities": {
                                "type": "object",
                                "description": "Investing cash flow details"
                            },
                            "financing_activities": {
                                "type": "object",
                                "description": "Financing cash flow details"
                            },
                            "net_change": {
                                "type": "number",
                                "description": "Net change in cash"
                            }
                        }
                    },
                    "financial_metrics": {
                        "type": "object",
                        "properties": {
                            "profitability": {
                                "type": "object",
                                "properties": {
                                    "gross_margin": {
                                        "type": "number",
                                        "description": "Gross profit margin"
                                    },
                                    "operating_margin": {
                                        "type": "number",
                                        "description": "Operating margin"
                                    },
                                    "net_margin": {
                                        "type": "number",
                                        "description": "Net profit margin"
                                    },
                                    "roi": {
                                        "type": "number",
                                        "description": "Return on investment"
                                    }
                                }
                            },
                            "liquidity": {
                                "type": "object",
                                "properties": {
                                    "current_ratio": {
                                        "type": "number",
                                        "description": "Current ratio"
                                    },
                                    "quick_ratio": {
                                        "type": "number",
                                        "description": "Quick ratio"
                                    },
                                    "cash_ratio": {
                                        "type": "number",
                                        "description": "Cash ratio"
                                    }
                                }
                            },
                            "efficiency": {
                                "type": "object",
                                "properties": {
                                    "asset_turnover": {
                                        "type": "number",
                                        "description": "Asset turnover ratio"
                                    },
                                    "inventory_turnover": {
                                        "type": "number",
                                        "description": "Inventory turnover ratio"
                                    },
                                    "receivables_turnover": {
                                        "type": "number",
                                        "description": "Receivables turnover ratio"
                                    }
                                }
                            }
                        }
                    },
                    "analysis": {
                        "type": "object",
                        "properties": {
                            "summary": {
                                "type": "string",
                                "description": "Executive summary"
                            },
                            "key_findings": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Key findings"
                            },
                            "trends": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Identified trends"
                            },
                            "recommendations": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Recommendations"
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
                            "updated_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "prepared_by": {
                                "type": "string",
                                "description": "Report preparer"
                            },
                            "reviewed_by": {
                                "type": "string",
                                "description": "Report reviewer"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "in_review", "final", "amended"],
                                "description": "Report status"
                            },
                            "version": {
                                "type": "string",
                                "description": "Report version"
                            },
                            "tags": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Relevant tags"
                            }
                        }
                    }
                }
            }
        ) 