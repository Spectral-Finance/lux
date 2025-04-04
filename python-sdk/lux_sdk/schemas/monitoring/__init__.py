"""
Monitoring Schemas

This module provides schemas for monitoring various aspects of systems and processes,
including performance metrics, error logs, and system health.
"""

from .performance_metrics import PerformanceMetricsSchema
from .error_log import ErrorLogSchema

__all__ = [
    'PerformanceMetricsSchema',
    'ErrorLogSchema'
]