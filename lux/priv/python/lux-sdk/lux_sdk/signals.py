"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, Optional, Type, TypeVar, Generic
import uuid
import json
from jsonschema import validate, ValidationError

T = TypeVar('T')

@dataclass
class SignalSchema:
    \"\"\"Base class for defining signal schemas in Lux.\"\"\"
    name: str
    version: str = "1.0.0"
    description: str = ""
    schema: Dict[str, Any] = field(default_factory=dict)
    tags: list[str] = field(default_factory=list)
    compatibility: str = "full"
    format: str = "json"

    def validate(self, payload: Any) -> None:
        \"\"\"Validate a payload against this schema.\"\"\"
        try:
            validate(instance=payload, schema=self.schema)
        except ValidationError as e:
            raise ValidationError(f"Schema validation failed: {str(e)}")

@dataclass
class Signal(Generic[T]):
    \"\"\"Represents a signal that can be sent between agents.\"\"\"
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    schema_id: Type[SignalSchema] = None
    payload: T = None
    sender: Optional[str] = None
    recipient: Optional[str] = None
    timestamp: datetime = field(default_factory=datetime.utcnow)
    topic: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        if self.schema_id and self.payload is not None:
            self.schema_id().validate(self.payload)

    def to_dict(self) -> Dict[str, Any]:
        \"\"\"Convert signal to a dictionary format.\"\"\"
        return {
            "id": self.id,
            "schema_id": self.schema_id.__name__ if self.schema_id else None,
            "payload": self.payload,
            "sender": self.sender,
            "recipient": self.recipient,
            "timestamp": self.timestamp.isoformat(),
            "topic": self.topic,
            "metadata": self.metadata
        }

    def to_json(self) -> str:
        \"\"\"Convert signal to JSON string.\"\"\"
        return json.dumps(self.to_dict())

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Signal':
        \"\"\"Create a signal from a dictionary.\"\"\"
        if "timestamp" in data and isinstance(data["timestamp"], str):
            data["timestamp"] = datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00"))
        return cls(**data)

    @classmethod
    def from_json(cls, json_str: str) -> 'Signal':
        \"\"\"Create a signal from a JSON string.\"\"\"
        return cls.from_dict(json.loads(json_str))

class TaskSchema(SignalSchema):
    \"\"\"Schema for task-related signals.\"\"\"
    def __init__(self):
        super().__init__(
            name="task",
            description="Represents a task assignment or update",
            schema={
                "type": "object",
                "properties": {
                    "type": {"type": "string", "enum": ["assignment", "status_update", "completion", "failure"]},
                    "task_id": {"type": "string"},
                    "title": {"type": "string"},
                    "description": {"type": "string"},
                    "status": {"type": "string", "enum": ["pending", "in_progress", "completed", "failed"]},
                    "progress": {"type": "number", "minimum": 0, "maximum": 100},
                    "metadata": {"type": "object"}
                },
                "required": ["type", "task_id", "title"]
            },
            tags=["task", "workflow"]
        )

class ObjectiveSchema(SignalSchema):
    \"\"\"Schema for objective-related signals.\"\"\"
    def __init__(self):
        super().__init__(
            name="objective",
            description="Represents an objective evaluation or update",
            schema={
                "type": "object",
                "properties": {
                    "type": {"type": "string", "enum": ["evaluate", "next_step", "status_update", "completion"]},
                    "objective_id": {"type": "string"},
                    "title": {"type": "string"},
                    "status": {"type": "string"},
                    "progress": {"type": "number", "minimum": 0, "maximum": 100},
                    "steps": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "description": {"type": "string"},
                                "status": {"type": "string", "enum": ["pending", "in_progress", "completed", "failed"]}
                            }
                        }
                    }
                },
                "required": ["type", "objective_id", "title"]
            },
            tags=["objective", "workflow"]
        )
""" 