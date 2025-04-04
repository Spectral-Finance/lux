"""
Emotional Intelligence Schemas

This module provides schemas for emotional intelligence related signals,
including emotional states, empathy, sentiment analysis, and social awareness.
"""

from .conflict_resolution import ConflictResolutionSchema
from .emotional_resonance import EmotionalResonanceSchema
from .emotional_state import EmotionalStateSchema
from .emotional_support import EmotionalSupportSchema
from .emotional_trigger import EmotionalTriggerSchema
from .empathy_response import EmpathyResponseSchema
from .mood_regulation import MoodRegulationSchema
from .relationship_dynamics import RelationshipDynamicsSchema
from .sentiment_analysis import SentimentAnalysisSchema
from .social_awareness import SocialAwarenessSchema

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