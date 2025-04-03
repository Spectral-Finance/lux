"""
Syntax Tree Schema

This schema represents the syntactic structure of text,
including parse trees, grammatical relationships, and linguistic annotations.
"""

from lux_sdk.signals import SignalSchema

SyntaxTreeSchema = SignalSchema({
    "type": "object",
    "properties": {
        "timestamp": {
            "type": "string",
            "format": "date-time"
        },
        "tree_id": {
            "type": "string",
            "description": "Unique identifier for the syntax tree"
        },
        "source_text": {
            "type": "string",
            "description": "Original text being parsed"
        },
        "root_node": {
            "type": "object",
            "properties": {
                "node_id": {
                    "type": "string",
                    "description": "Identifier for the root node"
                },
                "node_type": {
                    "type": "string",
                    "description": "Syntactic category of the node"
                },
                "children": {
                    "type": "array",
                    "items": {
                        "$ref": "#/definitions/node"
                    }
                }
            },
            "required": ["node_id", "node_type"]
        },
        "dependencies": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "relation_type": {
                        "type": "string",
                        "description": "Type of syntactic dependency"
                    },
                    "governor": {
                        "type": "string",
                        "description": "Head word in the dependency"
                    },
                    "dependent": {
                        "type": "string",
                        "description": "Dependent word"
                    }
                },
                "required": ["relation_type", "governor", "dependent"]
            }
        },
        "metadata": {
            "type": "object",
            "properties": {
                "parser_version": {
                    "type": "string",
                    "description": "Version of the parser used"
                },
                "grammar_formalism": {
                    "type": "string",
                    "description": "Grammar formalism used for parsing"
                },
                "confidence_score": {
                    "type": "number",
                    "minimum": 0,
                    "maximum": 1,
                    "description": "Confidence in the parse"
                }
            }
        }
    },
    "definitions": {
        "node": {
            "type": "object",
            "properties": {
                "node_id": {
                    "type": "string",
                    "description": "Identifier for this node"
                },
                "node_type": {
                    "type": "string",
                    "description": "Syntactic category"
                },
                "word": {
                    "type": "string",
                    "description": "Word or phrase at this node"
                },
                "features": {
                    "type": "object",
                    "properties": {
                        "pos_tag": {
                            "type": "string",
                            "description": "Part of speech tag"
                        },
                        "morphology": {
                            "type": "object",
                            "description": "Morphological features"
                        }
                    }
                },
                "children": {
                    "type": "array",
                    "items": {
                        "$ref": "#/definitions/node"
                    }
                }
            },
            "required": ["node_id", "node_type"]
        }
    },
    "required": ["timestamp", "tree_id", "source_text", "root_node"]
}) 