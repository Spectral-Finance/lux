"""
Environmental Awareness Schemas

This module provides schemas for environmental awareness and interaction,
including state monitoring, object recognition, and spatial relationships.
"""

from .environmental_state import EnvironmentalStateSchema
from .sensor_data import SensorDataSchema
from .spatial_relation import SpatialRelationSchema
from .object_recognition import ObjectRecognitionSchema
from .event_detection import EventDetectionSchema
from .contextual_awareness import ContextualAwarenessSchema
from .navigation_instruction import NavigationInstructionSchema
from .hazard_warning import HazardWarningSchema
from .weather_condition import WeatherConditionSchema
from .resource_availability import ResourceAvailabilitySchema

__all__ = [
    'EnvironmentalStateSchema',
    'SensorDataSchema',
    'SpatialRelationSchema',
    'ObjectRecognitionSchema',
    'EventDetectionSchema',
    'ContextualAwarenessSchema',
    'NavigationInstructionSchema',
    'HazardWarningSchema',
    'WeatherConditionSchema',
    'ResourceAvailabilitySchema'
] 