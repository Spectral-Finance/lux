"""
Creative Concept Schema

This schema represents creative concepts and ideas, including their development,
attributes, and relationships to other creative elements.
"""

from lux_sdk.signals import SignalSchema

CreativeConceptSchema = SignalSchema(
    name="creative_concept",
    version="1.0",
    description="Schema for representing creative concepts and their development",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "concept_id": {
                "type": "string",
                "description": "Unique identifier for this concept"
            },
            "title": {
                "type": "string",
                "description": "Title or name of the concept"
            },
            "description": {
                "type": "string",
                "description": "Detailed description of the concept"
            },
            "category": {
                "type": "string",
                "enum": ["visual", "narrative", "musical", "architectural", "product", "interaction", "other"],
                "description": "Primary category of the concept"
            },
            "inspiration": {
                "type": "object",
                "properties": {
                    "sources": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source_id": {
                                    "type": "string",
                                    "description": "Identifier for the inspiration source"
                                },
                                "type": {
                                    "type": "string",
                                    "enum": ["observation", "experience", "artwork", "nature", "technology", "culture", "other"],
                                    "description": "Type of inspiration source"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of how this source inspired the concept"
                                }
                            },
                            "required": ["source_id", "type"]
                        }
                    },
                    "influences": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "References to influential works or ideas"
                        }
                    }
                }
            },
            "elements": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "element_id": {
                            "type": "string",
                            "description": "Identifier for this element"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the element"
                        },
                        "type": {
                            "type": "string",
                            "description": "Type of creative element"
                        },
                        "attributes": {
                            "type": "object",
                            "description": "Element-specific attributes"
                        }
                    },
                    "required": ["element_id", "name", "type"]
                }
            },
            "development_stages": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "stage_id": {
                            "type": "string",
                            "description": "Identifier for this development stage"
                        },
                        "name": {
                            "type": "string",
                            "description": "Name of the stage"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["ideation", "exploration", "refinement", "validation", "completion"],
                            "description": "Current status of this stage"
                        },
                        "iterations": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "iteration_id": {
                                        "type": "string",
                                        "description": "Identifier for this iteration"
                                    },
                                    "changes": {
                                        "type": "array",
                                        "items": {
                                            "type": "string",
                                            "description": "Description of changes in this iteration"
                                        }
                                    },
                                    "feedback": {
                                        "type": "array",
                                        "items": {
                                            "type": "string",
                                            "description": "Feedback received for this iteration"
                                        }
                                    }
                                },
                                "required": ["iteration_id", "changes"]
                            }
                        }
                    },
                    "required": ["stage_id", "name", "status"]
                }
            },
            "evaluation": {
                "type": "object",
                "properties": {
                    "originality_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Score indicating concept originality"
                    },
                    "feasibility_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 1,
                        "description": "Score indicating implementation feasibility"
                    },
                    "impact_assessment": {
                        "type": "object",
                        "properties": {
                            "cultural": {
                                "type": "string",
                                "description": "Assessment of cultural impact"
                            },
                            "commercial": {
                                "type": "string",
                                "description": "Assessment of commercial potential"
                            },
                            "social": {
                                "type": "string",
                                "description": "Assessment of social impact"
                            }
                        }
                    },
                    "feedback": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "source": {
                                    "type": "string",
                                    "description": "Source of the feedback"
                                },
                                "content": {
                                    "type": "string",
                                    "description": "Feedback content"
                                },
                                "rating": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 5,
                                    "description": "Numerical rating if applicable"
                                }
                            },
                            "required": ["source", "content"]
                        }
                    }
                }
            },
            "relationships": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "related_concept_id": {
                            "type": "string",
                            "description": "ID of related concept"
                        },
                        "relationship_type": {
                            "type": "string",
                            "enum": ["inspiration", "variation", "evolution", "combination", "contrast"],
                            "description": "Type of relationship"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of the relationship"
                        }
                    },
                    "required": ["related_concept_id", "relationship_type"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "creator": {
                        "type": "string",
                        "description": "ID of concept creator"
                    },
                    "creation_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the concept was created"
                    },
                    "last_modified": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the concept was last modified"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    },
                    "rights": {
                        "type": "object",
                        "properties": {
                            "license": {
                                "type": "string",
                                "description": "License type"
                            },
                            "attribution": {
                                "type": "string",
                                "description": "Required attribution"
                            }
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "concept_id", "title", "description", "category", "elements", "development_stages"]
    }
) 