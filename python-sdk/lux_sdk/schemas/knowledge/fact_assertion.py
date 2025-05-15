"""
Schema for representing and validating factual assertions.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class FactAssertionSchema(SignalSchema):
    """Schema for representing fact assertions and their supporting evidence.
    
    This schema defines the structure for representing factual statements, their evidence,
    validation, relationships, and temporal aspects.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "assertion_id": "fact_20240403_153000",
            "source_id": "source_789",
            "fact": {
                "statement": "The average global temperature has increased by 1.1°C since pre-industrial times",
                "subject": "global temperature",
                "predicate": "has increased",
                "object": "1.1°C",
                "context": "since pre-industrial times",
                "confidence": 0.95
            },
            "evidence": [{
                "type": "research_paper",
                "source": "IPCC AR6 Report",
                "reference": "doi:10.1234/example",
                "relevance": 0.9,
                "reliability": 0.95,
                "excerpt": "Global surface temperature has increased by 1.1°C between 1850-1900 and 2011-2020",
                "verification_status": "verified"
            }],
            "validation": {
                "method": "peer_review",
                "validator": "climate_science_panel",
                "timestamp": "2024-04-02T10:00:00Z",
                "status": "validated",
                "confidence_score": 0.95
            },
            "relationships": [{
                "type": "supports",
                "related_fact_id": "fact_456",
                "strength": 0.8,
                "description": "Supports broader climate change trend assertion"
            }],
            "temporal_aspects": {
                "valid_from": "1850-01-01T00:00:00Z",
                "valid_until": "2020-12-31T23:59:59Z",
                "temporal_resolution": "yearly",
                "update_frequency": "as_needed"
            },
            "usage": {
                "permissions": ["public_use", "academic_citation"],
                "restrictions": ["requires_attribution"],
                "citation_format": "APA"
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "fact_curator",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "active",
                "review_history": [{
                    "reviewer": "expert_reviewer",
                    "timestamp": "2024-04-02T14:00:00Z",
                    "status": "approved",
                    "comments": "Well-supported by evidence"
                }],
                "tags": ["climate_science", "temperature", "global_warming"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="fact_assertion",
            version="1.0",
            description="Schema for representing fact assertions and their supporting evidence",
            schema={
                "type": "object",
                "required": ["timestamp", "assertion_id", "source_id", "fact", "evidence", "validation"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the fact assertion"
                    },
                    "assertion_id": {
                        "type": "string",
                        "description": "Unique identifier for the fact assertion"
                    },
                    "source_id": {
                        "type": "string",
                        "description": "Identifier of the fact source"
                    },
                    "fact": {
                        "type": "object",
                        "description": "The factual statement being asserted",
                        "required": ["statement"],
                        "properties": {
                            "statement": {
                                "type": "string",
                                "description": "The factual statement"
                            },
                            "subject": {
                                "type": "string",
                                "description": "Subject of the fact"
                            },
                            "predicate": {
                                "type": "string",
                                "description": "Predicate of the fact"
                            },
                            "object": {
                                "type": "string",
                                "description": "Object of the fact"
                            },
                            "context": {
                                "type": "string",
                                "description": "Additional context for the fact"
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Confidence score for the fact"
                            }
                        }
                    },
                    "evidence": {
                        "type": "array",
                        "description": "Supporting evidence for the fact",
                        "items": {
                            "type": "object",
                            "required": ["type", "source"],
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["research_paper", "dataset", "observation", "experiment", "expert_opinion"],
                                    "description": "Type of evidence"
                                },
                                "source": {
                                    "type": "string",
                                    "description": "Source of the evidence"
                                },
                                "reference": {
                                    "type": "string",
                                    "description": "Reference identifier (e.g., DOI)"
                                },
                                "relevance": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Relevance score of the evidence"
                                },
                                "reliability": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Reliability score of the evidence"
                                },
                                "excerpt": {
                                    "type": "string",
                                    "description": "Relevant excerpt from the evidence"
                                },
                                "verification_status": {
                                    "type": "string",
                                    "enum": ["unverified", "pending", "verified", "disputed"],
                                    "description": "Verification status of the evidence"
                                }
                            }
                        }
                    },
                    "validation": {
                        "type": "object",
                        "description": "Validation information for the fact",
                        "required": ["method", "status"],
                        "properties": {
                            "method": {
                                "type": "string",
                                "description": "Validation method used"
                            },
                            "validator": {
                                "type": "string",
                                "description": "Entity performing validation"
                            },
                            "timestamp": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Validation timestamp"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["pending", "validated", "rejected", "requires_review"],
                                "description": "Validation status"
                            },
                            "confidence_score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Validation confidence score"
                            }
                        }
                    },
                    "relationships": {
                        "type": "array",
                        "description": "Related facts and assertions",
                        "items": {
                            "type": "object",
                            "required": ["type", "related_fact_id"],
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["supports", "contradicts", "relates_to", "depends_on"],
                                    "description": "Type of relationship"
                                },
                                "related_fact_id": {
                                    "type": "string",
                                    "description": "ID of the related fact"
                                },
                                "strength": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Strength of the relationship"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the relationship"
                                }
                            }
                        }
                    },
                    "temporal_aspects": {
                        "type": "object",
                        "description": "Temporal information about the fact",
                        "properties": {
                            "valid_from": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Start of validity period"
                            },
                            "valid_until": {
                                "type": "string",
                                "format": "date-time",
                                "description": "End of validity period"
                            },
                            "temporal_resolution": {
                                "type": "string",
                                "description": "Temporal resolution of the fact"
                            },
                            "update_frequency": {
                                "type": "string",
                                "description": "How often the fact should be updated"
                            }
                        }
                    },
                    "usage": {
                        "type": "object",
                        "description": "Information about fact usage",
                        "properties": {
                            "permissions": {
                                "type": "array",
                                "description": "Allowed usage permissions",
                                "items": {"type": "string"}
                            },
                            "restrictions": {
                                "type": "array",
                                "description": "Usage restrictions",
                                "items": {"type": "string"}
                            },
                            "citation_format": {
                                "type": "string",
                                "description": "Required citation format"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the fact assertion",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the fact assertion"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Version of the fact assertion"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "deprecated", "retracted"],
                                "description": "Status of the fact assertion"
                            },
                            "review_history": {
                                "type": "array",
                                "description": "History of reviews",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "reviewer": {
                                            "type": "string",
                                            "description": "Reviewer identifier"
                                        },
                                        "timestamp": {
                                            "type": "string",
                                            "format": "date-time",
                                            "description": "Review timestamp"
                                        },
                                        "status": {
                                            "type": "string",
                                            "enum": ["pending", "approved", "rejected", "needs_revision"],
                                            "description": "Review status"
                                        },
                                        "comments": {
                                            "type": "string",
                                            "description": "Review comments"
                                        }
                                    }
                                }
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {"type": "string"}
                            }
                        }
                    }
                }
            }
        ) 