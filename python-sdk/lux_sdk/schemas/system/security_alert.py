"""
Security Alert Schema

This schema represents security alerts and incident notifications,
including threat detection, impact assessment, and response actions.
"""

from lux_sdk.signals import SignalSchema

SecurityAlertSchema = SignalSchema(
    name="security_alert",
    version="1.0",
    description="Schema for security alerts and incident notifications",
    schema={
        "type": "object",
        "properties": {
            "timestamp": {
                "type": "string",
                "format": "date-time"
            },
            "alert_id": {
                "type": "string",
                "description": "Unique identifier for this security alert"
            },
            "alert_type": {
                "type": "string",
                "enum": [
                    "intrusion_detection",
                    "malware_detection",
                    "authentication_failure",
                    "access_violation",
                    "data_breach",
                    "system_anomaly",
                    "policy_violation",
                    "configuration_change",
                    "vulnerability_detected"
                ],
                "description": "Type of security alert"
            },
            "severity": {
                "type": "string",
                "enum": ["critical", "high", "medium", "low", "info"],
                "description": "Severity level of the alert"
            },
            "status": {
                "type": "string",
                "enum": ["new", "investigating", "resolved", "false_positive", "escalated"],
                "description": "Current status of the alert"
            },
            "source": {
                "type": "object",
                "properties": {
                    "system": {
                        "type": "string",
                        "description": "System generating the alert"
                    },
                    "component": {
                        "type": "string",
                        "description": "Specific component"
                    },
                    "location": {
                        "type": "string",
                        "description": "Physical or network location"
                    },
                    "ip_address": {
                        "type": "string",
                        "description": "Source IP address"
                    }
                },
                "required": ["system"]
            },
            "target": {
                "type": "object",
                "properties": {
                    "system": {
                        "type": "string",
                        "description": "Targeted system"
                    },
                    "component": {
                        "type": "string",
                        "description": "Targeted component"
                    },
                    "location": {
                        "type": "string",
                        "description": "Physical or network location"
                    },
                    "ip_address": {
                        "type": "string",
                        "description": "Target IP address"
                    },
                    "assets_affected": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Affected assets"
                    }
                },
                "required": ["system"]
            },
            "threat_details": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Name of the threat"
                    },
                    "description": {
                        "type": "string",
                        "description": "Detailed description"
                    },
                    "category": {
                        "type": "string",
                        "enum": [
                            "malware",
                            "phishing",
                            "ddos",
                            "unauthorized_access",
                            "data_exfiltration",
                            "insider_threat",
                            "zero_day",
                            "misconfiguration"
                        ],
                        "description": "Threat category"
                    },
                    "indicators": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "description": "Type of indicator"
                                },
                                "value": {
                                    "type": "string",
                                    "description": "Indicator value"
                                },
                                "confidence": {
                                    "type": "string",
                                    "enum": ["high", "medium", "low"],
                                    "description": "Confidence level"
                                }
                            }
                        }
                    },
                    "attack_vector": {
                        "type": "string",
                        "description": "Method of attack"
                    },
                    "cve_references": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Related CVE references"
                    }
                },
                "required": ["name", "description", "category"]
            },
            "impact_assessment": {
                "type": "object",
                "properties": {
                    "scope": {
                        "type": "string",
                        "enum": ["individual", "department", "organization", "external"],
                        "description": "Scope of impact"
                    },
                    "confidentiality_impact": {
                        "type": "string",
                        "enum": ["none", "partial", "complete"],
                        "description": "Impact on data confidentiality"
                    },
                    "integrity_impact": {
                        "type": "string",
                        "enum": ["none", "partial", "complete"],
                        "description": "Impact on data integrity"
                    },
                    "availability_impact": {
                        "type": "string",
                        "enum": ["none", "partial", "complete"],
                        "description": "Impact on system availability"
                    },
                    "business_impact": {
                        "type": "string",
                        "enum": ["none", "low", "medium", "high", "critical"],
                        "description": "Impact on business operations"
                    }
                }
            },
            "response_actions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "action_id": {
                            "type": "string",
                            "description": "Unique identifier for action"
                        },
                        "type": {
                            "type": "string",
                            "enum": [
                                "containment",
                                "eradication",
                                "recovery",
                                "investigation",
                                "notification",
                                "documentation"
                            ],
                            "description": "Type of response action"
                        },
                        "description": {
                            "type": "string",
                            "description": "Description of action"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["pending", "in_progress", "completed", "failed"],
                            "description": "Status of action"
                        },
                        "assigned_to": {
                            "type": "string",
                            "description": "Person or team assigned"
                        },
                        "timestamp": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When action was taken"
                        },
                        "results": {
                            "type": "string",
                            "description": "Results of action"
                        }
                    },
                    "required": ["action_id", "type", "description"]
                }
            },
            "evidence": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "evidence_id": {
                            "type": "string",
                            "description": "Unique identifier for evidence"
                        },
                        "type": {
                            "type": "string",
                            "enum": ["log", "snapshot", "traffic", "file", "memory_dump"],
                            "description": "Type of evidence"
                        },
                        "location": {
                            "type": "string",
                            "description": "Location of evidence"
                        },
                        "hash": {
                            "type": "string",
                            "description": "Hash of evidence"
                        },
                        "timestamp": {
                            "type": "string",
                            "format": "date-time",
                            "description": "When evidence was collected"
                        }
                    },
                    "required": ["evidence_id", "type", "location"]
                }
            },
            "metadata": {
                "type": "object",
                "properties": {
                    "detection_method": {
                        "type": "string",
                        "description": "How the alert was detected"
                    },
                    "confidence_level": {
                        "type": "string",
                        "enum": ["high", "medium", "low"],
                        "description": "Confidence in alert"
                    },
                    "false_positive_rate": {
                        "type": "number",
                        "description": "Historical false positive rate"
                    },
                    "related_alerts": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Related alert IDs"
                    },
                    "tags": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Alert tags"
                    }
                }
            }
        },
        "required": [
            "timestamp",
            "alert_id",
            "alert_type",
            "severity",
            "status",
            "source",
            "threat_details"
        ]
    }
) 