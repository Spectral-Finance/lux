# Lux SDK for Python

[![PyPI version](https://badge.fury.io/py/lux-sdk.svg)](https://badge.fury.io/py/lux-sdk)
[![Python versions](https://img.shields.io/pypi/pyversions/lux-sdk.svg)](https://pypi.org/project/lux-sdk/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Python SDK for working with Lux signals. This package provides tools for creating, validating, and handling signals in the Lux ecosystem.

## Features

- Type-safe signal handling with JSON Schema validation
- Pre-defined schemas for common signal types
- Easy signal creation and validation
- Comprehensive test coverage

## Installation

```bash
pip install lux-sdk
```

## Quick Start

### Working with Signals

```python
from lux_sdk import Signal
from lux_sdk.signal_schema import MessageSchema, get_schema

# Create a signal using a predefined schema
message_schema = MessageSchema()
signal = Signal(
    schema_id=message_schema,
    payload={
        "message_id": "msg-123",
        "type": "text",
        "content": "Hello, Lux!",
        "format": "plain"
    },
    sender="my-app"
)

# Access signal properties
print(signal.id)  # Unique signal ID
print(signal.payload)  # Validated payload
print(signal.to_dict())  # Convert to dictionary

# Get a schema by name
task_schema = get_schema("task")
```

### Available Signal Schemas

The SDK provides several predefined schemas:

#### Task Schema
```python
from lux_sdk.signal_schema import TaskSchema

task_signal = Signal(
    schema_id=TaskSchema(),
    payload={
        "task_id": "task-123",
        "type": "assignment",
        "title": "Important task",
        "priority": 1,
        "status": "pending"
    }
)
```

#### Message Schema
```python
from lux_sdk.signal_schema import MessageSchema

message_signal = Signal(
    schema_id=MessageSchema(),
    payload={
        "message_id": "msg-123",
        "type": "text",
        "content": "Important update",
        "format": "markdown"
    }
)
```

#### Data Schema
```python
from lux_sdk.signal_schema import DataSchema

data_signal = Signal(
    schema_id=DataSchema(),
    payload={
        "data_id": "data-123",
        "type": "metrics",
        "format": "json",
        "content": {"value": 42}
    }
)
```

#### Status Schema
```python
from lux_sdk.signal_schema import StatusSchema

status_signal = Signal(
    schema_id=StatusSchema(),
    payload={
        "status_id": "status-123",
        "type": "health",
        "level": "info",
        "message": "System healthy"
    }
)
```

### Creating Custom Schemas

You can create custom signal schemas by extending the `SignalSchema` class:

```python
from lux_sdk import SignalSchema

class CustomSchema(SignalSchema):
    def __init__(self):
        super().__init__(
            name="custom",
            version="1.0",
            description="Custom signal schema",
            schema={
                "type": "object",
                "properties": {
                    "custom_id": {"type": "string"},
                    "value": {"type": "number"}
                },
                "required": ["custom_id", "value"]
            }
        )

# Use the custom schema
custom_signal = Signal(
    schema_id=CustomSchema(),
    payload={
        "custom_id": "custom-123",
        "value": 42
    }
)
```

## Development

### Setup

```bash
# Clone the repository
git clone https://github.com/SpectralFinance/lux.git
cd lux/python-sdk

# Install dependencies
pip install -e ".[dev]"

# Run tests
pytest
```

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=lux_sdk

# Run specific test file
pytest tests/test_signals.py
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Documentation

For full documentation, visit [Lux Documentation](https://github.com/SpectralFinance/lux/tree/main/lux/guides). 