"""
Education and Training Schemas

This module provides schemas for educational processes and training,
including learning objectives, curriculum design, and assessment.
"""

from .learning_objective import LearningObjectiveSchema
from .curriculum_design import CurriculumDesignSchema
from .assessment_criteria import AssessmentCriteriaSchema
from .progress_report import ProgressReportSchema
from .feedback_report import FeedbackReportSchema
from .skill_evaluation import SkillEvaluationSchema
from .learning_resource import LearningResourceSchema
from .competency_level import CompetencyLevelSchema
from .teaching_strategy import TeachingStrategySchema
from .adaptive_learning import AdaptiveLearningSchema
from .peer_assessment import PeerAssessmentSchema

__all__ = [
    'LearningObjectiveSchema',
    'CurriculumDesignSchema',
    'AssessmentCriteriaSchema',
    'ProgressReportSchema',
    'FeedbackReportSchema',
    'SkillEvaluationSchema',
    'LearningResourceSchema',
    'CompetencyLevelSchema',
    'TeachingStrategySchema',
    'AdaptiveLearningSchema',
    'PeerAssessmentSchema'
] 