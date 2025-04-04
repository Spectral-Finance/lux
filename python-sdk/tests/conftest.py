"""Test fixtures for the Lux SDK tests."""

import pytest
from lux_sdk.signals import SignalSchema

@pytest.fixture
def basic_schema():
    """A basic schema for testing."""
    return SignalSchema(
        name="test",
        version="1.0",
        description="Test schema",
        schema={
            "type": "object",
            "properties": {
                "message": {"type": "string"},
                "priority": {"type": "integer", "minimum": 1, "maximum": 5}
            },
            "required": ["message", "priority"],
            "additionalProperties": False
        }
    ) 