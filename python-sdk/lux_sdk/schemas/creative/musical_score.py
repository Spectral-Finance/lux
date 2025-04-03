"""
Musical Score Schema

This schema represents musical score elements and composition,
including notation, structure, and performance instructions.
"""

from lux_sdk.signals import SignalSchema

MusicalScoreSchema = SignalSchema(
    name="musical_score",
    version="1.0",
    description="Schema for musical score elements and composition",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "score_id": {
                "type": "string",
                "description": "Unique identifier for this score"
            },
            "title": {
                "type": "string",
                "description": "Title of the composition"
            },
            "composer": {
                "type": "string",
                "description": "Composer name"
            },
            "composition": {
                "type": "object",
                "properties": {
                    "key": {
                        "type": "string",
                        "description": "Musical key"
                    },
                    "time_signature": {
                        "type": "string",
                        "description": "Time signature"
                    },
                    "tempo": {
                        "type": "object",
                        "properties": {
                            "bpm": {
                                "type": "integer",
                                "description": "Beats per minute"
                            },
                            "marking": {
                                "type": "string",
                                "description": "Tempo marking"
                            }
                        }
                    }
                },
                "required": ["key", "time_signature"]
            },
            "sections": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "Section name"
                        },
                        "measures": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "number": {
                                        "type": "integer",
                                        "description": "Measure number"
                                    },
                                    "notes": {
                                        "type": "array",
                                        "items": {
                                            "type": "object",
                                            "properties": {
                                                "pitch": {"type": "string"},
                                                "duration": {"type": "string"},
                                                "dynamics": {"type": "string"}
                                            },
                                            "required": ["pitch", "duration"]
                                        }
                                    }
                                },
                                "required": ["number"]
                            }
                        }
                    },
                    "required": ["name", "measures"]
                }
            },
            "instrumentation": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "instrument": {
                            "type": "string",
                            "description": "Instrument name"
                        },
                        "clef": {
                            "type": "string",
                            "description": "Musical clef"
                        },
                        "range": {
                            "type": "object",
                            "properties": {
                                "low": {"type": "string"},
                                "high": {"type": "string"}
                            }
                        }
                    },
                    "required": ["instrument", "clef"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the score"
                    },
                    "created_at": {
                        "type": "string",
                        "format": "date-time",
                        "description": "Creation timestamp"
                    },
                    "version": {
                        "type": "string",
                        "description": "Version of the score"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Relevant tags"
                    }
                }
            }
        },
        "required": ["timestamp", "score_id", "title", "composer", "composition"]
    }
) 