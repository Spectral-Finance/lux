"""
Emotional Intelligence Schemas

This module provides schemas for emotional intelligence related signals,
including emotional states, empathy, sentiment analysis, and social awareness.
"""

from .emotional_state import EmotionalStateSchema
from .empathy_response import EmpathyResponseSchema
from .sentiment_analysis import SentimentAnalysisSchema
from .mood_regulation import MoodRegulationSchema
from .social_awareness import SocialAwarenessSchema
from .emotional_trigger import EmotionalTriggerSchema
from .relationship_dynamics import RelationshipDynamicsSchema
from .emotional_resonance import EmotionalResonanceSchema
from .conflict_resolution import ConflictResolutionSchema
from .emotional_support import EmotionalSupportSchema

__all__ = [
    'EmotionalStateSchema',
    'EmpathyResponseSchema',
    'SentimentAnalysisSchema',
    'MoodRegulationSchema',
    'SocialAwarenessSchema',
    'EmotionalTriggerSchema',
    'RelationshipDynamicsSchema',
    'EmotionalResonanceSchema',
    'ConflictResolutionSchema',
    'EmotionalSupportSchema'
] 