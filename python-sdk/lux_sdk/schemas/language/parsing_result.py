from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ParsingResultSchema(SignalSchema):
    """Schema for representing natural language parsing results.
    
    This schema defines the structure for parsing results, including
    syntactic analysis (POS tagging, dependency parsing) and semantic analysis
    (named entities, semantic roles, etc.).
    
    Example:
        {
            "timestamp": "2024-04-03T12:34:56Z",
            "parse_id": "parse-123456",
            "input_text": "John gave Mary the book in the library.",
            "language": "en",
            "syntactic_analysis": {
                "tokens": [
                    {
                        "text": "John",
                        "pos": "PROPN",
                        "lemma": "john",
                        "start": 0,
                        "end": 4
                    }
                ],
                "dependencies": [
                    {
                        "head": 1,
                        "dependent": 0,
                        "relation": "nsubj"
                    }
                ],
                "constituents": [
                    {
                        "label": "NP",
                        "start": 0,
                        "end": 4,
                        "children": []
                    }
                ]
            },
            "semantic_analysis": {
                "entities": [
                    {
                        "text": "John",
                        "type": "PERSON",
                        "start": 0,
                        "end": 4
                    }
                ],
                "semantic_roles": [
                    {
                        "predicate": "gave",
                        "agent": "John",
                        "patient": "book",
                        "recipient": "Mary"
                    }
                ],
                "coreference": [
                    {
                        "mentions": ["John", "he"],
                        "cluster_id": 1
                    }
                ]
            },
            "metadata": {
                "parser_version": "1.0.0",
                "processing_time_ms": 123
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="parsing_result",
            version="1.0",
            description="Schema for natural language parsing results",
            schema={
                "type": "object",
                "required": ["timestamp", "parse_id", "input_text", "language"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the parsing was performed"
                    },
                    "parse_id": {
                        "type": "string",
                        "description": "Unique identifier for this parsing result"
                    },
                    "input_text": {
                        "type": "string",
                        "description": "The original text that was parsed"
                    },
                    "language": {
                        "type": "string",
                        "description": "ISO 639-1 language code"
                    },
                    "syntactic_analysis": {
                        "type": "object",
                        "properties": {
                            "tokens": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["text", "pos", "start", "end"],
                                    "properties": {
                                        "text": {
                                            "type": "string",
                                            "description": "The token text"
                                        },
                                        "pos": {
                                            "type": "string",
                                            "description": "Part of speech tag"
                                        },
                                        "lemma": {
                                            "type": "string",
                                            "description": "Lemmatized form of the token"
                                        },
                                        "start": {
                                            "type": "integer",
                                            "description": "Start character position"
                                        },
                                        "end": {
                                            "type": "integer",
                                            "description": "End character position"
                                        }
                                    }
                                }
                            },
                            "dependencies": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["head", "dependent", "relation"],
                                    "properties": {
                                        "head": {
                                            "type": "integer",
                                            "description": "Index of the head token"
                                        },
                                        "dependent": {
                                            "type": "integer",
                                            "description": "Index of the dependent token"
                                        },
                                        "relation": {
                                            "type": "string",
                                            "description": "Type of dependency relation"
                                        }
                                    }
                                }
                            },
                            "constituents": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["label", "start", "end"],
                                    "properties": {
                                        "label": {
                                            "type": "string",
                                            "description": "Constituent label (e.g., NP, VP)"
                                        },
                                        "start": {
                                            "type": "integer",
                                            "description": "Start token index"
                                        },
                                        "end": {
                                            "type": "integer",
                                            "description": "End token index"
                                        },
                                        "children": {
                                            "type": "array",
                                            "items": {
                                                "type": "object"
                                            },
                                            "description": "Child constituents"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "semantic_analysis": {
                        "type": "object",
                        "properties": {
                            "entities": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["text", "type", "start", "end"],
                                    "properties": {
                                        "text": {
                                            "type": "string",
                                            "description": "Entity text"
                                        },
                                        "type": {
                                            "type": "string",
                                            "description": "Entity type (e.g., PERSON, ORG)"
                                        },
                                        "start": {
                                            "type": "integer",
                                            "description": "Start character position"
                                        },
                                        "end": {
                                            "type": "integer",
                                            "description": "End character position"
                                        }
                                    }
                                }
                            },
                            "semantic_roles": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["predicate"],
                                    "properties": {
                                        "predicate": {
                                            "type": "string",
                                            "description": "The main predicate"
                                        },
                                        "agent": {
                                            "type": "string",
                                            "description": "Agent of the action"
                                        },
                                        "patient": {
                                            "type": "string",
                                            "description": "Patient of the action"
                                        },
                                        "recipient": {
                                            "type": "string",
                                            "description": "Recipient of the action"
                                        }
                                    }
                                }
                            },
                            "coreference": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "required": ["mentions", "cluster_id"],
                                    "properties": {
                                        "mentions": {
                                            "type": "array",
                                            "items": {
                                                "type": "string"
                                            },
                                            "description": "Coreferent mentions"
                                        },
                                        "cluster_id": {
                                            "type": "integer",
                                            "description": "Unique identifier for this coreference cluster"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "parser_version": {
                                "type": "string",
                                "description": "Version of the parser used"
                            },
                            "processing_time_ms": {
                                "type": "integer",
                                "minimum": 0,
                                "description": "Processing time in milliseconds"
                            }
                        }
                    }
                }
            }
        ) 