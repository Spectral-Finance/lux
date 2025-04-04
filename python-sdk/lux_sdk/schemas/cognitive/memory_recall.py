"""
MemoryRecall Schema

This schema defines the structure for memory recall operations between agents. It's designed to:
- Request specific memories or knowledge
- Return relevant memories with context
- Include metadata about the recall process
- Track the reliability and relevance of recalled information

Example Usage:
```python
from lux_sdk.signals import Signal
from lux_sdk.schemas.cognitive.memory_recall import MemoryRecallSchema

# Create a memory recall request
signal = Signal(
    schema=MemoryRecallSchema,
    payload={
        "query": "What was the outcome of the last risk assessment?",
        "context": {
            "domain": "project_management",
            "time_frame": "last_month",
            "relevance_criteria": ["risk_level", "mitigation_steps"]
        },
        "recalled_items": [
            {
                "content": "Risk assessment identified two high-priority issues",
                "timestamp": "2024-03-15T14:30:00Z",
                "source": "project_meeting_notes",
                "confidence": 0.95,
                "metadata": {
                    "participants": ["risk_analyst", "project_manager"],
                    "document_id": "RA-2024-03-15"
                }
            },
            {
                "content": "Mitigation steps were approved and implemented",
                "timestamp": "2024-03-16T10:00:00Z",
                "source": "action_items_log",
                "confidence": 0.88,
                "metadata": {
                    "status": "completed",
                    "reviewer": "compliance_team"
                }
            }
        ],
        "recall_metrics": {
            "latency_ms": 150,
            "total_matches": 2,
            "filtered_matches": 2,
            "average_confidence": 0.915
        }
    }
)
```

Schema Structure:
- query: The memory recall request or question
- context: Parameters to focus the recall
  - domain: Area of knowledge to search
  - time_frame: Temporal context for the recall
  - relevance_criteria: Specific aspects to focus on
- recalled_items: Array of recalled memories, each with:
  - content: The actual remembered information
  - timestamp: When the memory was formed
  - source: Origin of the memory
  - confidence: Confidence in the recall (0-1)
  - metadata: Additional contextual information
- recall_metrics: Performance metrics of the recall operation

The schema enforces:
- Valid timestamps in ISO format
- Confidence scores between 0 and 1
- Required fields for each recalled item
- Consistent metadata structure
"""

from lux_sdk.signals import SignalSchema

SCHEMA = {
    "type": "object",
    "properties": {
        "query": {
            "type": "string",
            "description": "The memory recall request or question"
        },
        "context": {
            "type": "object",
            "properties": {
                "domain": {
                    "type": "string",
                    "description": "Area of knowledge to search"
                },
                "time_frame": {
                    "type": "string",
                    "description": "Temporal context for the recall"
                },
                "relevance_criteria": {
                    "type": "array",
                    "items": {
                        "type": "string"
                    },
                    "description": "Specific aspects to focus on"
                }
            },
            "required": ["domain"],
            "additionalProperties": True
        },
        "recalled_items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "content": {
                        "type": "string",
                        "description": "The actual remembered information"
                    },
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the memory was formed"
                    },
                    "source": {
                        "type": "string",
                        "description": "Origin of the memory"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence in the recall (0-1)"
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional contextual information"
                    }
                },
                "required": ["content", "timestamp", "source", "confidence"],
                "additionalProperties": False
            },
            "description": "Array of recalled memories"
        },
        "recall_metrics": {
            "type": "object",
            "properties": {
                "latency_ms": {
                    "type": "number",
                    "minimum": 0,
                    "description": "Time taken to recall in milliseconds"
                },
                "total_matches": {
                    "type": "integer",
                    "minimum": 0,
                    "description": "Total number of matching memories found"
                },
                "filtered_matches": {
                    "type": "integer",
                    "minimum": 0,
                    "description": "Number of memories after filtering"
                },
                "average_confidence": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Average confidence across all recalls"
                }
            },
            "required": ["latency_ms", "total_matches", "filtered_matches"],
            "additionalProperties": True
        }
    },
    "required": ["query", "context", "recalled_items"],
    "additionalProperties": False
}

MemoryRecallSchema = SignalSchema(
    name="lux.cognitive.memory_recall",
    version="1.0",
    description="Schema for memory recall operations between agents",
    schema=SCHEMA
) 