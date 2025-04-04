"""
Source Citation Schema

This schema represents source citations and references,
including bibliographic information, credibility assessment, and usage context.
"""

from lux_sdk.signals import SignalSchema

SourceCitationSchema = SignalSchema(
    name="source_citation",
    version="1.0",
    description="Schema for source citations and references in knowledge management",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "citation_id": {
                "type": "string",
                "description": "Unique identifier for this citation"
            },
            "source_type": {
                "type": "string",
                "enum": [
                    "academic_paper",
                    "book",
                    "journal_article",
                    "conference_proceeding",
                    "website",
                    "report",
                    "dataset",
                    "personal_communication",
                    "other"
                ],
                "description": "Type of source being cited"
            },
            "bibliographic_info": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "Title of the source"
                    },
                    "authors": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Author's name"
                                },
                                "affiliation": {
                                    "type": "string",
                                    "description": "Author's affiliation"
                                },
                                "identifier": {
                                    "type": "object",
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "enum": ["orcid", "doi", "other"],
                                            "description": "Type of identifier"
                                        },
                                        "value": {
                                            "type": "string",
                                            "description": "Identifier value"
                                        }
                                    }
                                }
                            },
                            "required": ["name"]
                        }
                    },
                    "publication_info": {
                        "type": "object",
                        "properties": {
                            "publisher": {
                                "type": "string",
                                "description": "Publisher name"
                            },
                            "publication_date": {
                                "type": "string",
                                "format": "date",
                                "description": "Date of publication"
                            },
                            "volume": {
                                "type": "string",
                                "description": "Volume number"
                            },
                            "issue": {
                                "type": "string",
                                "description": "Issue number"
                            },
                            "pages": {
                                "type": "string",
                                "description": "Page range"
                            },
                            "doi": {
                                "type": "string",
                                "description": "Digital Object Identifier"
                            }
                        },
                        "required": ["publication_date"]
                    }
                },
                "required": ["title", "authors"]
            },
            "access_info": {
                "type": "object",
                "properties": {
                    "url": {
                        "type": "string",
                        "description": "URL where source can be accessed"
                    },
                    "access_date": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the source was accessed"
                    },
                    "access_type": {
                        "type": "string",
                        "enum": ["open_access", "subscription", "purchase", "restricted"],
                        "description": "Type of access"
                    },
                    "license": {
                        "type": "string",
                        "description": "License information"
                    }
                }
            },
            "credibility_assessment": {
                "type": "object",
                "properties": {
                    "peer_reviewed": {
                        "type": "boolean",
                        "description": "Whether the source is peer-reviewed"
                    },
                    "impact_factor": {
                        "type": "number",
                        "description": "Impact factor of the publication"
                    },
                    "citation_count": {
                        "type": "integer",
                        "minimum": 0,
                        "description": "Number of citations"
                    },
                    "authority_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10,
                        "description": "Authority score of the source"
                    },
                    "verification_status": {
                        "type": "string",
                        "enum": ["verified", "pending", "disputed", "retracted"],
                        "description": "Verification status of the source"
                    }
                }
            },
            "usage_context": {
                "type": "object",
                "properties": {
                    "purpose": {
                        "type": "string",
                        "description": "Purpose of citation"
                    },
                    "relevance_score": {
                        "type": "number",
                        "minimum": 0,
                        "maximum": 10,
                        "description": "Relevance to the context"
                    },
                    "cited_content": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "excerpt": {
                                    "type": "string",
                                    "description": "Cited text or content"
                                },
                                "location": {
                                    "type": "string",
                                    "description": "Location in source"
                                },
                                "context": {
                                    "type": "string",
                                    "description": "Context of usage"
                                }
                            },
                            "required": ["excerpt"]
                        }
                    },
                    "related_concepts": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Related concepts or keywords"
                        }
                    }
                },
                "required": ["purpose"]
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "citation_style": {
                        "type": "string",
                        "description": "Citation style used"
                    },
                    "language": {
                        "type": "string",
                        "description": "Language of the source"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "description": "Relevant tags"
                        }
                    },
                    "notes": {
                        "type": "string",
                        "description": "Additional notes"
                    },
                    "last_updated": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When citation was last updated"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "citation_id",
            "source_type",
            "bibliographic_info",
            "usage_context"
        ]
    }
) 