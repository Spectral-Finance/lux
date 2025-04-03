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

__all__ = [
    'EnvironmentalStateSchema',
    'SensorDataSchema',
    'SpatialRelationSchema',
    'ObjectRecognitionSchema',
    'EventDetectionSchema'
] 