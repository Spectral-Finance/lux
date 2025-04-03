"""
Emotional Intelligence Schemas

This module contains schemas for emotional intelligence related signals, including:
- Emotion recognition and analysis
- Empathy response generation
- Emotional regulation and management
"""

from lux_sdk.schemas.emotional.emotion_recognition import EmotionRecognitionSchema
from lux_sdk.schemas.emotional.empathy_response import EmpathyResponseSchema
from lux_sdk.schemas.emotional.emotional_regulation import EmotionalRegulationSchema

__all__ = [
    "EmotionRecognitionSchema",
    "EmpathyResponseSchema",
    "EmotionalRegulationSchema"
] 