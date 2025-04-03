"""
Data Collection Schema

This schema represents data collection activities and configurations,
including collection methods, data sources, and collection policies.
"""

from lux_sdk.signals import SignalSchema

DataCollectionSchema = SignalSchema(
    name="data_collection",
    version="1.0",
    description="Schema for defining and tracking data collection activities",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "collection_id": {
                "type": "string",
                "description": "Unique identifier for this collection activity"
            },
            "name": {
                "type": "string",
                "description": "Name of the data collection"
            },
            "description": {
                "type": "string",
                "description": "Description of the data collection purpose"
            },
            "data_sources": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "source_id": {
                            "type": "string",
                            "description": "Identifier for the data source"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["api", "database", "file", "stream", "sensor"],
                            "description": "Type of data source"
                        },
                        "configuration": {
                            "type": "object",
                            "properties": {
                                "connection_string": {
                                    "type": "string",
                                    "description": "Connection details for the source"
                                },
                                "authentication": {
                                    "type": "object",
                                    "properties": {
                                        "method": {
                                            "type": "string",
                                            "enum": ["api_key", "oauth", "basic", "token"],
                                            "description": "Authentication method"
                                        },
                                        "credentials": {
                                            "type": "object",
                                            "description": "Authentication credentials"
                                        }
                                    },
                                    "required": ["method"]
                                },
                                "format": {
                                    "type": "string",
                                    "enum": ["json", "csv", "xml", "binary", "text"],
                                    "description": "Data format"
                                }
                            },
                            "required": ["connection_string"]
                        }
                    },
                    "required": ["source_id", "type", "configuration"]
                }
            },
            "collection_policy": {
                "type": "object",
                "properties": {
                    "frequency": {
                        "type": "string",
                        "enum": ["once", "hourly", "daily", "weekly", "monthly", "continuous"],
                        "description": "Collection frequency"
                    },
                    "retention_period": {
                        "type": "object",
                        "properties": {
                            "duration": {
                                "type": "integer",
                                "description": "Duration to retain data"
                            },
                            "unit": {
                                "type": "string",
                                "enum": ["hours", "days", "weeks", "months", "years"],
                                "description": "Time unit for retention duration"
                            }
                        },
                        "required": ["duration", "unit"]
                    },
                    "data_quality": {
                        "type": "object",
                        "properties": {
                            "validation_rules": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "References to validation rules"
                                }
                            },
                            "cleaning_steps": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "Data cleaning steps to apply"
                                }
                            }
                        }
                    }
                },
                "required": ["frequency"]
            },
            "processing_pipeline": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "step_id": {
                            "type": "string",
                            "description": "Identifier for the processing step"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["transform", "validate", "enrich", "aggregate", "filter"],
                            "description": "Type of processing step"
                        },
                        "configuration": {
                            "type": "object",
                            "description": "Configuration for the processing step"
                        }
                    },
                    "required": ["step_id", "type"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "created_at": {
                        "type": "string",
                        "format": "date-time"
                    },
                    "created_by": {
                        "type": "string",
                        "description": "Creator of the collection"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["active", "paused", "completed", "failed"],
                        "description": "Current status of collection"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        }
                    }
                }
            }
        },
        "required": ["timestamp", "collection_id", "name", "data_sources", "collection_policy"]
    }
) 