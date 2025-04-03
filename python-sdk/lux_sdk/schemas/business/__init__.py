"""
Business Process Schemas

This module provides schemas for business operations and management,
including market analysis, financial reporting, and strategic planning.
"""

from .market_analysis import MarketAnalysisSchema
from .financial_report import FinancialReportSchema
from .project_proposal import ProjectProposalSchema
from .risk_assessment import RiskAssessmentSchema
from .strategy_plan import StrategyPlanSchema
from .customer_feedback import CustomerFeedbackSchema
from .resource_allocation import ResourceAllocationSchema
from .performance_metric import PerformanceMetricSchema
from .competitive_analysis import CompetitiveAnalysisSchema
from .operational_process import OperationalProcessSchema
from .compliance_check import ComplianceCheckSchema

__all__ = [
    'MarketAnalysisSchema',
    'FinancialReportSchema',
    'ProjectProposalSchema',
    'RiskAssessmentSchema',
    'StrategyPlanSchema',
    'CustomerFeedbackSchema',
    'ResourceAllocationSchema',
    'PerformanceMetricSchema',
    'CompetitiveAnalysisSchema',
    'OperationalProcessSchema',
    'ComplianceCheckSchema'
] 