"""
Scientific Research Schemas

This module provides schemas for scientific research processes,
including experiment design, hypothesis testing, and data analysis.
"""

from .experiment_design import ExperimentDesignSchema
from .hypothesis_test import HypothesisTestSchema
from .experiment_protocol import ExperimentProtocolSchema
from .research_data import ResearchDataSchema
from .data_collection import DataCollectionSchema
from .statistical_analysis import StatisticalAnalysisSchema

__all__ = [
    'ExperimentDesignSchema',
    'HypothesisTestSchema',
    'ExperimentProtocolSchema',
    'ResearchDataSchema',
    'DataCollectionSchema',
    'StatisticalAnalysisSchema'
]