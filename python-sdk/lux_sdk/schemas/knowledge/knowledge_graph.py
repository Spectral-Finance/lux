"""
KnowledgeGraph Schema

This schema defines the structure for representing knowledge as a graph of concepts
and their relationships. It enables agents to share and update their understanding
of concept relationships and dependencies.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "graph_id": "kg_machine_learning_basics",
    "nodes": [
        {
            "id": "supervised_learning",
            "type": "concept",
            "name": "Supervised Learning",
            "description": "Learning from labeled training data",
            "confidence": 0.95
        },
        {
            "id": "classification",
            "type": "technique",
            "name": "Classification",
            "description": "Predicting categorical labels",
            "confidence": 0.9
        }
    ],
    "edges": [
        {
            "source": "supervised_learning",
            "target": "classification",
            "relationship": "includes",
            "weight": 0.8,
            "properties": {
                "bidirectional": false,
                "examples": ["spam detection", "image recognition"]
            }
        }
    ],
    "metadata": {
        "domain": "machine_learning",
        "version": "1.0",
        "last_updated": "2024-03-20T15:30:00Z",
        "confidence_threshold": 0.7
    }
}
```
"""

from lux_sdk.signals import SignalSchema

KnowledgeGraphSchema = SignalSchema(
    name="knowledge_graph",
    version="1.0",
    description="Schema for representing knowledge as a graph of concepts and relationships",
    schema={
        "type": "object",
        "required": ["timestamp", "graph_id", "nodes", "edges", "metadata"],
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time",
                "description": "When the knowledge graph was created or updated"
            },
            "graph_id": {
                "type": "string",
                "description": "Unique identifier for the knowledge graph"
            },
            "nodes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["id", "type", "name", "confidence"],
                    "properties": {
                        "id": {
                            "type": "string",
                            "description": "Unique node identifier"
                        },
                        "type": {
                            "type": "string",
                            "description": "Node type (e.g., concept, entity, fact)"
                        },
                        "name": {
                            "type": "string",
                            "description": "Human-readable name"
                        },
                        "description": {
                            "type": "string",
                            "description": "Optional description of the node"
                        },
                        "confidence": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Confidence in node's accuracy"
                        }
                    }
                }
            },
            "edges": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["source", "target", "relationship", "weight"],
                    "properties": {
                        "source": {
                            "type": "string",
                            "description": "Source node ID"
                        },
                        "target": {
                            "type": "string",
                            "description": "Target node ID"
                        },
                        "relationship": {
                            "type": "string",
                            "description": "Type of relationship"
                        },
                        "weight": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Relationship strength"
                        },
                        "properties": {
                            "type": "object",
                            "description": "Additional edge properties"
                        }
                    }
                }
            },
            "metadata": {
                "type": "object",
                "required": ["domain", "version", "last_updated"],
                "properties": {
                    "domain": {
                        "type": "string",
                        "description": "Knowledge domain"
                    },
                    "version": {
                        "type": "string",
                        "description": "Graph version"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "confidence_threshold": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Minimum confidence threshold"
                    }
                }
            }
        },
        "additionalProperties": False
    }
) 