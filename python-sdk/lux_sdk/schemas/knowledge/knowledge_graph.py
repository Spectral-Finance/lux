"""
Knowledge Graph Schema

This schema represents knowledge graphs and semantic networks,
including nodes, edges, and their relationships and properties.
"""

from lux_sdk.signals import SignalSchema

KnowledgeGraphSchema = SignalSchema(
    name="knowledge_graph",
    version="1.0",
    description="Schema for knowledge graphs and semantic networks",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "graph_id": {
                "type": "string",
                "description": "Unique identifier for this knowledge graph"
            },
            "nodes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "node_id": {
                            "type": "string",
                            "description": "Unique identifier for the node"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["concept", "entity", "event", "property", "class", "instance"],
                            "description": "Type of node"
                        },
                        "label": {
                            "type": "string",
                            "description": "Human-readable label for the node"
                        },
                        "properties": {
                            "type": "object",
                            "description": "Additional properties of the node",
                            "additionalProperties": True
                        },
                        "aliases": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "Alternative names or labels"
                            }
                        },
                        "source": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Source type (e.g., document, database, api)"
                                },
                                "identifier": {
                                    "type": "string",
                                    "description": "Source identifier"
                                }
                            }
                        }
                    },
                    "required": ["node_id", "type", "label"]
                }
            },
            "edges": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "edge_id": {
                            "type": "string",
                            "description": "Unique identifier for the edge"
                        },
                        "source_id": {
                            "type": "string",
                            "description": "ID of source node"
                        },
                        "target_id": {
                            "type": "string",
                            "description": "ID of target node"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["is_a", "has_property", "related_to", "part_of", "causes", "depends_on", "similar_to", "custom"],
                            "description": "Type of relationship"
                        },
                        "label": {
                            "type": "string",
                            "description": "Human-readable label for the relationship"
                        },
                        "properties": {
                            "type": "object",
                            "description": "Additional properties of the edge",
                            "additionalProperties": True
                        },
                        "weight": {
                            "type": "number",
                            "minimum": 0,
                            "maximum": 1,
                            "description": "Weight or strength of the relationship"
                        },
                        "provenance": {
                            "type": "object",
                            "properties": {
                                "confidence": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Confidence score"
                                },
                                "method": {
                                    "type": "string",
                                    "description": "Method used to establish relationship"
                                },
                                "timestamp": {
                                    "type": "string",
                                    "format": "date-time",
                                    "description": "When relationship was established"
                                }
                            }
                        }
                    },
                    "required": ["edge_id", "source_id", "target_id", "type"]
                }
            },
            "subgraphs": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "subgraph_id": {
                            "type": "string",
                            "description": "Unique identifier for the subgraph"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the subgraph"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the subgraph"
                        },
                        "node_ids": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "IDs of nodes in the subgraph"
                            }
                        },
                        "edge_ids": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "IDs of edges in the subgraph"
                            }
                        }
                    },
                    "required": ["subgraph_id", "name", "node_ids", "edge_ids"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the knowledge graph"
                    },
                    "description": {
                        "type": "string",
                        "description": "Description of the knowledge graph"
                    },
                    "domain": {
                        "type": "string",
                        "description": "Domain or subject area"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the graph"
                    },
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the graph"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Last update timestamp"
                    },
                    "license": {
                        "type": "string",
                        "description": "License information"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Relevant tags"
                        }
                    }
                },
                "required": ["name", "domain", "version"]
            },
            "statistics": {
                "type": "object",
                "properties": {
                    "node_count": {
                        "type": "integer",
                        "description": "Total number of nodes"
                    },
                    "edge_count": {
                        "type": "integer",
                        "description": "Total number of edges"
                    },
                    "density": {
                        "type": "number",
                        "description": "Graph density"
                    },
                    "node_type_distribution": {
                        "type": "object",
                        "description": "Distribution of node types",
                        "additionalProperties": {
                            "type": "integer"
                        }
                    },
                    "edge_type_distribution": {
                        "type": "object",
                        "description": "Distribution of edge types",
                        "additionalProperties": {
                            "type": "integer"
                        }
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "graph_id",
            "nodes",
            "edges",
            "metadata"
        ]
    }
) 