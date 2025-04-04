"""Core signal schema functionality for the Lux SDK.

This module provides the base SignalSchema class that all signal schemas must inherit from.
It supports both JSON Schema validation and optionally Pydantic models for validation.
"""

from abc import ABC
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Type, TypeVar, Generic
import uuid
import json
from jsonschema import validate as jsonschema_validate, ValidationError

try:
    from pydantic import ValidationError as PydanticValidationError
    PYDANTIC_AVAILABLE = True
except ImportError:
    PYDANTIC_AVAILABLE = False

# Type variable for generic signal payloads
T = TypeVar('T')

class SignalSchema(ABC):
    """Abstract base class for all signal schemas.
    
    This class provides the core functionality for defining and validating signal schemas
    in the Lux ecosystem. Each schema must provide a name, version, description, and a
    JSON Schema definition that describes the structure of valid signals.
    
    Optionally, a Pydantic model can be provided for validation if Pydantic is available
    in the developer's environment.
    
    Example with JSON Schema:
        ```python
        class CustomSchema(SignalSchema):
            def __init__(self):
                super().__init__(
                    name="custom",
                    version="1.0",
                    description="A custom signal schema",
                    schema={
                        "type": "object",
                        "properties": {
                            "custom_id": {"type": "string"},
                            "value": {"type": "number"}
                        },
                        "required": ["custom_id"]
                    }
                )
        ```
    
    Example with Pydantic (if available):
        ```python
        from pydantic import BaseModel, Field
        
        class CustomPayload(BaseModel):
            custom_id: str
            value: float = Field(default=0.0)
        
        class CustomSchema(SignalSchema):
            def __init__(self):
                super().__init__(
                    name="custom",
                    version="1.0",
                    description="A custom signal schema",
                    model=CustomPayload
                )
        ```
    """
    
    def __init__(
        self,
        name: str,
        version: str,
        description: str,
        schema: Optional[Dict[str, Any]] = None,
        model: Any = None
    ) -> None:
        """Initialize a new signal schema.
        
        Args:
            name: The name of the schema (e.g., "message", "task")
            version: The schema version (e.g., "1.0")
            description: A human-readable description of the schema
            schema: The JSON Schema definition for this signal type
            model: Optional Pydantic model class for validation
        
        Raises:
            ValueError: If any of the required fields are empty or invalid
        """
        if not name or not isinstance(name, str):
            raise ValueError("Schema name must be a non-empty string")
        if not version or not isinstance(version, str):
            raise ValueError("Schema version must be a non-empty string")
        if not description or not isinstance(description, str):
            raise ValueError("Schema description must be a non-empty string")
        
        self.name = name
        self.version = version
        self.description = description
        self.model = model
        
        # If a model is provided and it's a Pydantic model, use its schema
        if model is not None and hasattr(model, "model_json_schema"):
            self.schema = model.model_json_schema()
        elif schema is not None:
            if not isinstance(schema, dict):
                raise ValueError("Schema must be a dictionary")
            if schema.get("type") != "object":
                raise ValueError("Schema must define an object type")
            self.schema = schema
        else:
            raise ValueError("Either schema or a valid model must be provided")
    
    def validate(self, payload: Dict[str, Any]) -> bool:
        """Validate a signal payload against this schema.
        
        Args:
            payload: The signal payload to validate
        
        Returns:
            bool: True if the payload is valid according to the schema
        """
        try:
            self.validate_strict(payload)
            return True
        except Exception:  # Catch both jsonschema and potential pydantic errors
            return False
    
    def _normalize_payload(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Normalize payload types to match schema requirements."""
        if not self.schema:
            return payload

        normalized = {}
        properties = self.schema.get("properties", {})
        
        for key, value in payload.items():
            if key not in properties:
                normalized[key] = value
                continue
                
            prop_type = properties[key].get("type")
            try:
                if prop_type == "integer" and isinstance(value, str):
                    try:
                        normalized[key] = int(value)
                    except ValueError:
                        normalized[key] = value
                elif prop_type == "number" and isinstance(value, str):
                    try:
                        normalized[key] = float(value)
                    except ValueError:
                        normalized[key] = value
                elif prop_type == "string" and not isinstance(value, str):
                    normalized[key] = str(value)
                else:
                    normalized[key] = value
            except Exception:
                normalized[key] = value
                
        return normalized

    def _format_error_message(self, error_msg: str, field: str, value: Any = None) -> str:
        """Format error messages consistently."""
        if "is a required property" in error_msg:
            return f"Required property '{field}' was not present"
        elif "is not of type" in error_msg:
            type_name = error_msg.split("'")[3]  # Extract type from error message
            return f"'{value}' is not of type '{type_name}'"
        elif "is less than the minimum" in error_msg:
            min_val = error_msg.split("minimum of ")[1]
            return f"'{value}' is less than the minimum of {min_val}"
        elif "is greater than the maximum" in error_msg:
            max_val = error_msg.split("maximum of ")[1]
            return f"'{value}' is greater than the maximum of {max_val}"
        elif "Additional properties are not allowed" in error_msg:
            extra_field = error_msg.split("'")[1]
            return f"Additional properties are not allowed ('{extra_field}' was unexpected)"
        return error_msg

    def validate_strict(self, payload: Dict[str, Any]) -> None:
        """Strictly validate a signal payload against this schema.
        
        Like validate(), but raises an exception with details if validation fails.
        
        Args:
            payload: The signal payload to validate
        
        Raises:
            ValidationError: If validation fails, with a normalized error message
        """
        normalized_payload = self._normalize_payload(payload)
        
        try:
            if self.model is not None and hasattr(self.model, "model_validate"):
                try:
                    self.model.model_validate(normalized_payload)
                except PydanticValidationError as e:
                    # Convert Pydantic error to normalized format
                    error = e.errors()[0]
                    field = error["loc"][0] if len(error["loc"]) == 1 else error["loc"][-1]
                    msg = error["msg"].lower()
                    ctx = error.get("ctx", {})

                    # Get the value from the nested structure
                    value = normalized_payload
                    for loc in error["loc"]:
                        value = value.get(loc) if isinstance(value, dict) else None

                    if "field required" in msg:
                        raise ValidationError(f"Required property '{field}' was not present")
                    elif "not a valid integer" in msg:
                        raise ValidationError(f"'{value}' is not of type 'integer'")
                    elif "not a valid string" in msg:
                        raise ValidationError(f"'{value}' is not of type 'string'")
                    elif "greater than or equal to" in msg:
                        min_val = ctx.get("ge") if "ge" in ctx else ctx.get("gt")
                        raise ValidationError(f"'{value}' is less than the minimum of {min_val}")
                    elif "less than or equal to" in msg:
                        max_val = ctx.get("le") if "le" in ctx else ctx.get("lt")
                        raise ValidationError(f"'{value}' is greater than the maximum of {max_val}")
                    else:
                        raise ValidationError(f"Invalid value for field '{field}': {msg}")
            else:
                try:
                    jsonschema_validate(instance=normalized_payload, schema=self.schema)
                except Exception as e:
                    # Extract the main error message without the schema details
                    msg = str(e).split("\n")[0]
                    
                    # Handle required property errors
                    if "is a required property" in msg:
                        field = msg.split("'")[1]
                        raise ValidationError(self._format_error_message(msg, field))
                    
                    # Handle type errors
                    elif "is not of type" in msg:
                        field = msg.split("instance")[1].split("'")[1] if "instance[" in msg else None
                        value = normalized_payload.get(field) if field else msg.split("'")[1]
                        raise ValidationError(self._format_error_message(msg, field, value))
                    
                    # Handle range errors
                    elif "is less than the minimum" in msg or "is greater than the maximum" in msg:
                        field = msg.split("instance")[1].split("'")[1] if "instance[" in msg else None
                        value = normalized_payload.get(field) if field else msg.split(" ")[0]
                        raise ValidationError(self._format_error_message(msg, field, value))
                    
                    # Handle additional properties
                    elif "Additional properties are not allowed" in msg:
                        raise ValidationError(self._format_error_message(msg, "", None))
                    
                    # Default case
                    raise ValidationError(msg)
        except ValidationError:
            raise
        except Exception as e:
            raise ValidationError(str(e))
    
    @property
    def required_fields(self) -> list[str]:
        """Get the list of required fields for this schema.
        
        Returns:
            list[str]: The names of all required fields
        """
        return self.schema.get("required", [])

class ValidationError(Exception):
    """Raised when signal validation fails."""
    pass

@dataclass
class Signal(Generic[T]):
    """Represents a signal that can be sent between agents."""
    schema: SignalSchema
    payload: T
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    sender: Optional[str] = None
    recipient: Optional[str] = None
    timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    topic: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        """Validate the payload against the schema after initialization."""
        if self.schema and self.payload is not None:
            self.schema.validate_strict(self.payload)

    def to_dict(self) -> Dict[str, Any]:
        """Convert signal to a dictionary format."""
        return {
            "id": self.id,
            "payload": self.payload,
            "sender": self.sender,
            "recipient": self.recipient,
            "timestamp": self.timestamp.isoformat(),
            "topic": self.topic,
            "metadata": self.metadata
        }

    def to_json(self) -> str:
        """Convert signal to JSON string."""
        return json.dumps(self.to_dict())

    @classmethod
    def from_dict(cls, data: Dict[str, Any], schema: SignalSchema) -> 'Signal':
        """Create a signal from a dictionary."""
        # Remove schema-related fields if present
        data = {k: v for k, v in data.items() if k not in ("schema_name", "schema_version")}
        
        # Convert timestamp string to datetime
        if "timestamp" in data and isinstance(data["timestamp"], str):
            data["timestamp"] = datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00"))
        
        return cls(schema=schema, **data)

    @classmethod
    def from_json(cls, json_str: str, schema: SignalSchema) -> 'Signal':
        """Create a signal from a JSON string."""
        return cls.from_dict(json.loads(json_str), schema)
