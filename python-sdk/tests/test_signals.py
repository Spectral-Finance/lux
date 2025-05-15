"""Tests for the core signal schema functionality."""

import pytest
from datetime import datetime, timezone
from lux_sdk.signals import Signal, SignalSchema, ValidationError

try:
    from pydantic import BaseModel, Field
    PYDANTIC_AVAILABLE = True
except ImportError:
    PYDANTIC_AVAILABLE = False

# Test Schema Definitions
BASIC_SCHEMA = {
    "type": "object",
    "properties": {
        "message": {"type": "string"},
        "priority": {"type": "integer", "minimum": 1, "maximum": 5},
        "tags": {"type": "array", "items": {"type": "string"}}
    },
    "required": ["message", "priority"],
    "additionalProperties": False
}

NESTED_SCHEMA = {
    "type": "object",
    "properties": {
        "data": {
            "type": "object",
            "properties": {
                "value": {"type": "integer"},
                "unit": {"type": "string"}
            },
            "required": ["value", "unit"],
            "additionalProperties": False
        }
    },
    "required": ["data"],
    "additionalProperties": False
}

class TestSignalSchemaInitialization:
    """Tests for SignalSchema initialization and basic properties."""
    
    def test_valid_json_schema_initialization(self):
        """Test initialization with a valid JSON Schema."""
        schema = SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            schema=BASIC_SCHEMA
        )
        assert schema.name == "test"
        assert schema.version == "1.0"
        assert schema.description == "Test schema"
        assert schema.schema == BASIC_SCHEMA
        assert schema.required_fields == ["message", "priority"]
        assert schema.model is None

    def test_invalid_schema_initialization(self):
        """Test initialization with invalid parameters."""
        with pytest.raises(ValueError, match="Schema name must be a non-empty string"):
            SignalSchema(name="", version="1.0", description="test", schema=BASIC_SCHEMA)
        
        with pytest.raises(ValueError, match="Schema version must be a non-empty string"):
            SignalSchema(name="test", version="", description="test", schema=BASIC_SCHEMA)
        
        with pytest.raises(ValueError, match="Schema description must be a non-empty string"):
            SignalSchema(name="test", version="1.0", description="", schema=BASIC_SCHEMA)
        
        with pytest.raises(ValueError, match="Schema must be a dictionary"):
            SignalSchema(name="test", version="1.0", description="test", schema="not a dict")
        
        with pytest.raises(ValueError, match="Schema must define an object type"):
            SignalSchema(
                name="test",
                version="1.0",
                description="test",
                schema={"type": "string"}
            )

    @pytest.mark.skipif(not PYDANTIC_AVAILABLE, reason="Pydantic not installed")
    def test_pydantic_schema_initialization(self):
        """Test initialization with a Pydantic model."""
        class TestModel(BaseModel):
            message: str
            priority: int = Field(ge=1, le=5)

        schema = SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            model=TestModel
        )
        assert schema.name == "test"
        assert schema.model == TestModel
        assert isinstance(schema.schema, dict)
        assert schema.schema["type"] == "object"
        assert schema.schema["properties"]["message"]["type"] == "string"
        assert schema.schema["properties"]["priority"]["type"] == "integer"
        assert schema.schema["properties"]["priority"]["minimum"] == 1
        assert schema.schema["properties"]["priority"]["maximum"] == 5
        assert schema.schema["required"] == ["message", "priority"]

class TestSignalSchemaValidation:
    """Tests for SignalSchema validation functionality."""

    def test_basic_schema_validation(self):
        """Test validation with a basic schema."""
        schema = SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            schema=BASIC_SCHEMA
        )

        # Test missing required field
        assert_validation_error(schema, {"priority": 1}, "Required property 'message' was not present")
        
        # Test invalid type
        assert_validation_error(schema, {"message": "test", "priority": "high"}, "'high' is not of type 'integer'")
        
        # Test value out of range
        assert_validation_error(schema, {"message": "test", "priority": 0}, "'0' is less than the minimum of 1")
        
        # Test additional property
        assert_validation_error(schema, {"message": "test", "priority": 1, "extra": "field"}, "Additional properties are not allowed ('extra' was unexpected)")
        
        # Test valid payload
        assert schema.validate({
            "message": "test",
            "priority": 1,
            "tags": ["important"]
        })

    def test_nested_schema_validation(self):
        """Test validation with a nested schema."""
        schema = SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            schema=NESTED_SCHEMA
        )

        # Test missing nested required field
        assert_validation_error(schema, {"data": {"unit": "meters"}}, "Required property 'value' was not present")
        
        # Test additional property in nested object
        assert_validation_error(schema, {"data": {"value": 42, "unit": "meters", "extra": "field"}}, "Additional properties are not allowed ('extra' was unexpected)")
        
        # Test valid payload
        assert schema.validate({
            "data": {"value": 42, "unit": "meters"}
        })

    def test_strict_validation(self):
        """Test strict validation that raises exceptions."""
        schema = SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            schema=BASIC_SCHEMA
        )

        # Valid payload should not raise
        schema.validate_strict({"message": "test", "priority": 3})

        # Invalid payload should raise ValidationError with descriptive message
        with pytest.raises(ValidationError, match="Required property 'priority' was not present"):
            schema.validate_strict({"message": "test"})

    @pytest.mark.skipif(not PYDANTIC_AVAILABLE, reason="Pydantic not installed")
    def test_pydantic_validation(self):
        """Test validation with a Pydantic model."""
        class DataModel(BaseModel):
            value: int = Field(ge=0)
            unit: str

        class TestModel(BaseModel):
            data: DataModel

        schema = SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            model=TestModel
        )
        
        # Test missing field
        assert_validation_error(schema, {"data": {"unit": "meters"}}, "Required property 'value' was not present")
        
        # Test value constraint
        assert_validation_error(schema, {"data": {"value": -1, "unit": "meters"}}, "'-1' is less than the minimum of 0")
        
        # Test valid payload
        assert schema.validate({
            "data": {"value": 42, "unit": "meters"}
        })

    @pytest.mark.skipif(not PYDANTIC_AVAILABLE, reason="Pydantic not installed")
    def test_validation_equivalence(self):
        """Test that JSON Schema and Pydantic validation are equivalent."""
        class TestModel(BaseModel):
            message: str
            priority: int = Field(ge=1, le=5)

        json_schema = SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            schema=BASIC_SCHEMA
        )

        pydantic_schema = SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            model=TestModel
        )

        # Test valid cases
        valid_payloads = [
            {"message": "test", "priority": 1},
            {"message": "test", "priority": 3},
            {"message": "test", "priority": 5}
        ]

        for payload in valid_payloads:
            assert json_schema.validate(payload) == pydantic_schema.validate(payload)

        # Test invalid cases
        invalid_payloads = [
            {},  # Missing required fields
            {"message": "test"},  # Missing priority
            {"message": "test", "priority": 0},  # Priority too low
            {"message": "test", "priority": 6},  # Priority too high
            {"message": 123, "priority": 3},  # Wrong type for message
            {"message": "test", "priority": "3"},  # Wrong type for priority
        ]

        for payload in invalid_payloads:
            assert json_schema.validate(payload) == pydantic_schema.validate(payload)

class TestSignal:
    """Tests for Signal class functionality."""

    @pytest.fixture
    def basic_schema(self):
        return SignalSchema(
            name="test",
            version="1.0",
            description="Test schema",
            schema=BASIC_SCHEMA
        )

    def test_signal_creation(self, basic_schema):
        """Test basic signal creation and validation."""
        signal = Signal(
            schema=basic_schema,
            payload={"message": "test", "priority": 3}
        )
        assert signal.id is not None
        assert isinstance(signal.timestamp, datetime)
        assert signal.schema == basic_schema
        assert signal.payload == {"message": "test", "priority": 3}

    def test_signal_creation_with_invalid_payload(self, basic_schema):
        """Test signal creation with invalid payload."""
        with pytest.raises(ValidationError, match="Required property 'priority' was not present"):
            Signal(
                schema=basic_schema,
                payload={"message": "test"}  # Missing priority
            )

    def test_signal_serialization(self, basic_schema):
        """Test signal serialization to and from JSON."""
        original = Signal(
            schema=basic_schema,
            payload={"message": "test", "priority": 3},
            sender="agent1",
            recipient="agent2",
            topic="test-topic",
            metadata={"key": "value"}
        )

        # Convert to JSON and back
        json_str = original.to_json()
        restored = Signal.from_json(json_str, basic_schema)

        # Check all fields are preserved
        assert restored.schema == original.schema
        assert restored.payload == original.payload
        assert restored.sender == original.sender
        assert restored.recipient == original.recipient
        assert restored.topic == original.topic
        assert restored.metadata == original.metadata
        
        # Check timestamp handling
        assert isinstance(restored.timestamp, datetime)
        assert restored.timestamp.tzinfo is not None  # Should be timezone-aware

    def test_signal_with_all_fields(self, basic_schema):
        """Test signal creation with all possible fields."""
        now = datetime.now(timezone.utc)
        signal = Signal(
            id="custom-id",
            schema=basic_schema,
            payload={"message": "test", "priority": 3},
            sender="sender-id",
            recipient="recipient-id",
            timestamp=now,
            topic="test-topic",
            metadata={"key": "value"}
        )

        assert signal.id == "custom-id"
        assert signal.sender == "sender-id"
        assert signal.recipient == "recipient-id"
        assert signal.timestamp == now
        assert signal.topic == "test-topic"
        assert signal.metadata == {"key": "value"}

def assert_validation_error(schema: SignalSchema, payload: dict, expected_msg: str):
    """Helper to assert validation errors with specific messages."""
    with pytest.raises(ValidationError) as exc_info:
        schema.validate_strict(payload)
    assert str(exc_info.value) == expected_msg

def test_type_coercion():
    """Test type coercion during validation."""
    schema = SignalSchema(
        name="test",
        version="1.0",
        description="Test schema",
        schema=BASIC_SCHEMA
    )
    
    # Test string to integer coercion
    payload = {
        "message": "test",
        "priority": "3",
        "tags": ["test"]
    }
    assert schema.validate(payload)
    
    # Test non-coercible string
    assert_validation_error(
        schema,
        {"message": "test", "priority": "invalid"},
        "'invalid' is not of type 'integer'"
    )

def test_signal_creation():
    """Test signal creation and serialization."""
    schema = SignalSchema(
        name="test",
        version="1.0",
        description="Test schema",
        schema=BASIC_SCHEMA
    )
    
    payload = {
        "message": "test",
        "priority": 1,
        "tags": ["test"]
    }
    
    signal = Signal(
        schema=schema,
        payload=payload,
        sender="test_sender",
        recipient="test_recipient",
        topic="test_topic"
    )
    
    # Test serialization
    signal_dict = signal.to_dict()
    assert signal_dict["payload"] == payload
    assert signal_dict["sender"] == "test_sender"
    assert signal_dict["recipient"] == "test_recipient"
    assert signal_dict["topic"] == "test_topic"
    assert isinstance(signal_dict["timestamp"], str)
    
    # Test deserialization
    new_signal = Signal.from_dict(signal_dict, schema)
    assert new_signal.payload == payload

def test_signal_creation_with_invalid_payload():
    """Test signal creation with invalid payload."""
    schema = SignalSchema(
        name="test",
        version="1.0",
        description="Test schema",
        schema=BASIC_SCHEMA
    )
    
    # Test missing required field
    assert_validation_error(
        schema,
        {"message": "test"},
        "Required property 'priority' was not present"
    )