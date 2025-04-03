"""
Semantic Role Schema

This schema represents semantic roles and thematic relations in natural language,
including predicate-argument structure, thematic roles, and semantic dependencies.
"""

from lux_sdk.signals import SignalSchema

SemanticRoleSchema = SignalSchema(
    name="semantic_role",
    version="1.0",
    description="Schema for semantic roles and thematic relations in natural language",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "role_id": {
                "type": "string",
                "description": "Unique identifier for this semantic role annotation"
            },
            "text": {
                "type": "string",
                "description": "The text being analyzed"
            },
            "predicate": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "The predicate text"
                    },
                    "lemma": {
                        "type": "string",
                        "description": "Lemmatized form of the predicate"
                    },
                    "position": {
                        "type": "object",
                        "properties": {
                            "start": {
                                "type": "integer",
                                "description": "Start character position"
                            },
                            "end": {
                                "type": "integer",
                                "description": "End character position"
                            }
                        },
                        "required": ["start", "end"]
                    },
                    "sense": {
                        "type": "string",
                        "description": "Predicate sense or meaning"
                    },
                    "voice": {
                        "type": "string",
                        "enum": ["active", "passive"],
                        "description": "Voice of the predicate"
                    }
                },
                "required": ["text", "position"]
            },
            "arguments": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "The argument text"
                        },
                        "role": {
                            "type": "string",
                            "enum": [
                                "agent",
                                "patient",
                                "theme",
                                "experiencer",
                                "beneficiary",
                                "instrument",
                                "location",
                                "time",
                                "manner",
                                "purpose",
                                "cause",
                                "goal",
                                "source",
                                "path",
                                "other"
                            ],
                            "description": "Thematic role of the argument"
                        },
                        "position": {
                            "type": "object",
                            "properties": {
                                "start": {
                                    "type": "integer",
                                    "description": "Start character position"
                                },
                                "end": {
                                    "type": "integer",
                                    "description": "End character position"
                                }
                            },
                            "required": ["start", "end"]
                        },
                        "properties": {
                            "type": "object",
                            "properties": {
                                "core": {
                                    "type": "boolean",
                                    "description": "Whether this is a core argument"
                                },
                                "implicit": {
                                    "type": "boolean",
                                    "description": "Whether the argument is implicit"
                                },
                                "coreferent": {
                                    "type": "string",
                                    "description": "ID of coreferent mention if any"
                                }
                            }
                        }
                    },
                    "required": ["text", "role", "position"]
                }
            },
            "dependencies": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "type": {
                            "type": "string",
                            "description": "Type of dependency relation"
                        },
                        "governor": {
                            "type": "object",
                            "properties": {
                                "text": {
                                    "type": "string",
                                    "description": "Governor text"
                                },
                                "position": {
                                    "type": "object",
                                    "properties": {
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
                            "required": ["text", "position"]
                        },
                        "dependent": {
                            "type": "object",
                            "properties": {
                                "text": {
                                    "type": "string",
                                    "description": "Dependent text"
                                },
                                "position": {
                                    "type": "object",
                                    "properties": {
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
                            "required": ["text", "position"]
                        }
                    },
                    "required": ["type", "governor", "dependent"]
                }
            },
            "frame": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the semantic frame"
                    },
                    "elements": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "role": {
                                    "type": "string",
                                    "description": "Frame element role"
                                },
                                "text": {
                                    "type": "string",
                                    "description": "Frame element text"
                                },
                                "core": {
                                    "type": "boolean",
                                    "description": "Whether this is a core frame element"
                                }
                            },
                            "required": ["role", "text"]
                        }
                    }
                },
                "required": ["name", "elements"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "parser": {
                        "type": "string",
                        "description": "Parser used for analysis"
                    },
                    "confidence": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Confidence score"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language of the text"
                    },
                    "model_version": {
                        "type": "string",
                        "description": "Version of the model used"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "role_id",
            "text",
            "predicate",
            "arguments"
        ]
    }
) 