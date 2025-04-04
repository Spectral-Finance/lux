"""
SecurityPolicy Schema

This schema defines the structure for representing security policies and controls,
including access controls, data protection, incident response, and compliance monitoring.
It helps organizations maintain robust security practices and compliance requirements.

Example usage:
```python
{
    "timestamp": "2024-03-20T15:30:00Z",
    "policy_id": "sec_20240320_153000",
    "organization_id": "org_789",
    "policy_overview": {
        "name": "Enterprise Security Policy",
        "description": "Comprehensive security policy for enterprise systems",
        "scope": "All enterprise systems and data",
        "objectives": [
            "Ensure data confidentiality",
            "Maintain system integrity",
            "Guarantee service availability"
        ],
        "compliance_frameworks": [{
            "framework": "ISO 27001",
            "version": "2022",
            "controls": ["A.5.1", "A.6.1", "A.7.1"]
        }]
    },
    "access_controls": {
        "authentication": {
            "methods": ["password", "biometric", "certificate"],
            "mfa_required": true,
            "password_policy": {
                "min_length": 12,
                "complexity": {
                    "uppercase": true,
                    "lowercase": true,
                    "numbers": true,
                    "special_chars": true
                },
                "expiration_days": 90,
                "history": 24
            }
        }
    }
}
```
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class SecurityPolicySchema(SignalSchema):
    def __init__(self):
        super().__init__(
            name="security_policy",
            version="1.0",
            description="Schema for representing security policies and controls",
            schema={
                "type": "object",
                "required": ["timestamp", "policy_id", "organization_id", "policy_overview", "access_controls"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO 8601 timestamp of when the policy was created"
                    },
                    "policy_id": {
                        "type": "string",
                        "description": "Unique identifier for the security policy"
                    },
                    "organization_id": {
                        "type": "string",
                        "description": "Identifier of the organization"
                    },
                    "policy_overview": {
                        "type": "object",
                        "description": "Overview of the security policy",
                        "required": ["name", "description", "scope"],
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Policy name"
                            },
                            "description": {
                                "type": "string",
                                "description": "Policy description"
                            },
                            "scope": {
                                "type": "string",
                                "description": "Policy scope"
                            },
                            "objectives": {
                                "type": "array",
                                "description": "Policy objectives",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "applicability": {
                                "type": "array",
                                "description": "Applicable domains/systems",
                                "items": {
                                    "type": "string"
                                }
                            },
                            "compliance_frameworks": {
                                "type": "array",
                                "description": "Related compliance frameworks",
                                "items": {
                                    "type": "object",
                                    "required": ["framework", "version"],
                                    "properties": {
                                        "framework": {
                                            "type": "string",
                                            "description": "Framework name"
                                        },
                                        "version": {
                                            "type": "string",
                                            "description": "Framework version"
                                        },
                                        "controls": {
                                            "type": "array",
                                            "description": "Related controls",
                                            "items": {
                                                "type": "string"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "access_controls": {
                        "type": "object",
                        "description": "Access control policies",
                        "required": ["authentication", "authorization"],
                        "properties": {
                            "authentication": {
                                "type": "object",
                                "description": "Authentication requirements",
                                "required": ["methods", "mfa_required"],
                                "properties": {
                                    "methods": {
                                        "type": "array",
                                        "description": "Allowed authentication methods",
                                        "items": {
                                            "type": "string",
                                            "enum": ["password", "biometric", "certificate", "token", "oauth", "saml"]
                                        }
                                    },
                                    "mfa_required": {
                                        "type": "boolean",
                                        "description": "Multi-factor authentication requirement"
                                    },
                                    "password_policy": {
                                        "type": "object",
                                        "description": "Password requirements",
                                        "properties": {
                                            "min_length": {
                                                "type": "integer",
                                                "minimum": 8,
                                                "description": "Minimum password length"
                                            },
                                            "complexity": {
                                                "type": "object",
                                                "description": "Complexity requirements",
                                                "properties": {
                                                    "uppercase": {
                                                        "type": "boolean",
                                                        "description": "Requires uppercase"
                                                    },
                                                    "lowercase": {
                                                        "type": "boolean",
                                                        "description": "Requires lowercase"
                                                    },
                                                    "numbers": {
                                                        "type": "boolean",
                                                        "description": "Requires numbers"
                                                    },
                                                    "special_chars": {
                                                        "type": "boolean",
                                                        "description": "Requires special characters"
                                                    }
                                                }
                                            },
                                            "expiration_days": {
                                                "type": "integer",
                                                "minimum": 1,
                                                "description": "Password expiration period"
                                            },
                                            "history": {
                                                "type": "integer",
                                                "minimum": 1,
                                                "description": "Password history count"
                                            }
                                        }
                                    }
                                }
                            },
                            "authorization": {
                                "type": "object",
                                "description": "Authorization framework",
                                "required": ["model"],
                                "properties": {
                                    "model": {
                                        "type": "string",
                                        "enum": ["RBAC", "ABAC", "ACL", "PBAC"],
                                        "description": "Access control model (RBAC, ABAC, etc.)"
                                    },
                                    "roles": {
                                        "type": "array",
                                        "description": "Defined roles",
                                        "items": {
                                            "type": "object",
                                            "required": ["name", "permissions"],
                                            "properties": {
                                                "name": {
                                                    "type": "string",
                                                    "description": "Role name"
                                                },
                                                "permissions": {
                                                    "type": "array",
                                                    "description": "Role permissions",
                                                    "items": {
                                                        "type": "string"
                                                    }
                                                },
                                                "constraints": {
                                                    "type": "array",
                                                    "description": "Role constraints",
                                                    "items": {
                                                        "type": "string"
                                                    }
                                                }
                                            }
                                        }
                                    },
                                    "delegation": {
                                        "type": "object",
                                        "description": "Delegation rules",
                                        "required": ["allowed"],
                                        "properties": {
                                            "allowed": {
                                                "type": "boolean",
                                                "description": "Delegation allowed"
                                            },
                                            "restrictions": {
                                                "type": "array",
                                                "description": "Delegation restrictions",
                                                "items": {
                                                    "type": "string"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "data_protection": {
                        "type": "object",
                        "description": "Data protection policies",
                        "properties": {
                            "classification": {
                                "type": "object",
                                "description": "Data classification framework",
                                "properties": {
                                    "levels": {
                                        "type": "array",
                                        "description": "Classification levels",
                                        "items": {
                                            "type": "object",
                                            "required": ["name", "description"],
                                            "properties": {
                                                "name": {
                                                    "type": "string",
                                                    "description": "Level name"
                                                },
                                                "description": {
                                                    "type": "string",
                                                    "description": "Level description"
                                                },
                                                "handling": {
                                                    "type": "array",
                                                    "description": "Handling requirements",
                                                    "items": {
                                                        "type": "string"
                                                    }
                                                },
                                                "controls": {
                                                    "type": "array",
                                                    "description": "Required controls",
                                                    "items": {
                                                        "type": "string"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "encryption": {
                                "type": "object",
                                "description": "Encryption requirements",
                                "properties": {
                                    "at_rest": {
                                        "type": "object",
                                        "description": "Data at rest encryption",
                                        "required": ["required"],
                                        "properties": {
                                            "required": {
                                                "type": "boolean",
                                                "description": "Encryption required"
                                            },
                                            "algorithms": {
                                                "type": "array",
                                                "description": "Approved algorithms",
                                                "items": {
                                                    "type": "string",
                                                    "enum": ["AES-256", "AES-192", "AES-128", "RSA-4096", "RSA-2048"]
                                                }
                                            },
                                            "key_management": {
                                                "type": "object",
                                                "description": "Key management requirements"
                                            }
                                        }
                                    },
                                    "in_transit": {
                                        "type": "object",
                                        "description": "Data in transit encryption",
                                        "required": ["required"],
                                        "properties": {
                                            "required": {
                                                "type": "boolean",
                                                "description": "Encryption required"
                                            },
                                            "protocols": {
                                                "type": "array",
                                                "description": "Approved protocols",
                                                "items": {
                                                    "type": "string",
                                                    "enum": ["TLS 1.3", "TLS 1.2", "SSH-2"]
                                                }
                                            },
                                            "minimum_strength": {
                                                "type": "string",
                                                "description": "Minimum encryption strength"
                                            }
                                        }
                                    }
                                }
                            },
                            "retention": {
                                "type": "object",
                                "description": "Data retention policies",
                                "properties": {
                                    "periods": {
                                        "type": "array",
                                        "description": "Retention periods",
                                        "items": {
                                            "type": "object",
                                            "required": ["data_type", "duration"],
                                            "properties": {
                                                "data_type": {
                                                    "type": "string",
                                                    "description": "Type of data"
                                                },
                                                "duration": {
                                                    "type": "string",
                                                    "description": "Retention duration"
                                                },
                                                "justification": {
                                                    "type": "string",
                                                    "description": "Retention justification"
                                                }
                                            }
                                        }
                                    },
                                    "disposal": {
                                        "type": "object",
                                        "description": "Data disposal requirements",
                                        "properties": {
                                            "methods": {
                                                "type": "array",
                                                "description": "Approved disposal methods",
                                                "items": {
                                                    "type": "string",
                                                    "enum": ["deletion", "shredding", "overwriting", "degaussing", "physical_destruction"]
                                                }
                                            },
                                            "verification": {
                                                "type": "string",
                                                "description": "Disposal verification requirements"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "incident_response": {
                        "type": "object",
                        "description": "Incident response procedures",
                        "properties": {
                            "classification": {
                                "type": "object",
                                "description": "Incident classification",
                                "properties": {
                                    "levels": {
                                        "type": "array",
                                        "description": "Severity levels",
                                        "items": {
                                            "type": "object",
                                            "required": ["level", "description", "response_time"],
                                            "properties": {
                                                "level": {
                                                    "type": "string",
                                                    "enum": ["critical", "high", "medium", "low"],
                                                    "description": "Severity level"
                                                },
                                                "description": {
                                                    "type": "string",
                                                    "description": "Level description"
                                                },
                                                "response_time": {
                                                    "type": "string",
                                                    "description": "Required response time"
                                                },
                                                "escalation": {
                                                    "type": "array",
                                                    "description": "Escalation path",
                                                    "items": {
                                                        "type": "string"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            "procedures": {
                                "type": "array",
                                "description": "Response procedures",
                                "items": {
                                    "type": "object",
                                    "required": ["type", "steps"],
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "description": "Incident type"
                                        },
                                        "steps": {
                                            "type": "array",
                                            "description": "Response steps",
                                            "items": {
                                                "type": "string"
                                            }
                                        },
                                        "contacts": {
                                            "type": "array",
                                            "description": "Contact list",
                                            "items": {
                                                "type": "string"
                                            }
                                        },
                                        "resources": {
                                            "type": "array",
                                            "description": "Required resources",
                                            "items": {
                                                "type": "string"
                                            }
                                        }
                                    }
                                }
                            },
                            "reporting": {
                                "type": "object",
                                "description": "Incident reporting requirements",
                                "properties": {
                                    "internal": {
                                        "type": "array",
                                        "description": "Internal reporting requirements",
                                        "items": {
                                            "type": "string"
                                        }
                                    },
                                    "external": {
                                        "type": "array",
                                        "description": "External reporting requirements",
                                        "items": {
                                            "type": "string"
                                        }
                                    },
                                    "timeframes": {
                                        "type": "object",
                                        "description": "Reporting timeframes"
                                    }
                                }
                            }
                        }
                    },
                    "compliance_monitoring": {
                        "type": "object",
                        "description": "Compliance monitoring framework",
                        "properties": {
                            "audits": {
                                "type": "object",
                                "description": "Audit requirements",
                                "required": ["frequency", "scope"],
                                "properties": {
                                    "frequency": {
                                        "type": "string",
                                        "enum": ["monthly", "quarterly", "semi-annual", "annual"],
                                        "description": "Audit frequency"
                                    },
                                    "scope": {
                                        "type": "array",
                                        "description": "Audit scope",
                                        "items": {
                                            "type": "string"
                                        }
                                    },
                                    "methods": {
                                        "type": "array",
                                        "description": "Audit methods",
                                        "items": {
                                            "type": "string"
                                        }
                                    },
                                    "evidence": {
                                        "type": "array",
                                        "description": "Required evidence",
                                        "items": {
                                            "type": "string"
                                        }
                                    }
                                }
                            },
                            "metrics": {
                                "type": "array",
                                "description": "Security metrics",
                                "items": {
                                    "type": "object",
                                    "required": ["name", "description", "calculation"],
                                    "properties": {
                                        "name": {
                                            "type": "string",
                                            "description": "Metric name"
                                        },
                                        "description": {
                                            "type": "string",
                                            "description": "Metric description"
                                        },
                                        "calculation": {
                                            "type": "string",
                                            "description": "Calculation method"
                                        },
                                        "threshold": {
                                            "type": "string",
                                            "description": "Acceptable threshold"
                                        },
                                        "frequency": {
                                            "type": "string",
                                            "enum": ["daily", "weekly", "monthly", "quarterly"],
                                            "description": "Measurement frequency"
                                        }
                                    }
                                }
                            },
                            "reporting": {
                                "type": "object",
                                "description": "Compliance reporting",
                                "required": ["schedule", "recipients"],
                                "properties": {
                                    "schedule": {
                                        "type": "string",
                                        "description": "Reporting schedule"
                                    },
                                    "recipients": {
                                        "type": "array",
                                        "description": "Report recipients",
                                        "items": {
                                            "type": "string"
                                        }
                                    },
                                    "format": {
                                        "type": "string",
                                        "enum": ["pdf", "html", "docx", "xlsx"],
                                        "description": "Report format"
                                    },
                                    "content": {
                                        "type": "array",
                                        "description": "Required content",
                                        "items": {
                                            "type": "string"
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the security policy",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Policy creator"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Policy version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "review", "active", "superseded", "archived"],
                                "description": "Policy status"
                            },
                            "review_history": {
                                "type": "array",
                                "description": "Policy review history",
                                "items": {
                                    "type": "object",
                                    "required": ["reviewer", "date"],
                                    "properties": {
                                        "reviewer": {
                                            "type": "string",
                                            "description": "Reviewer identifier"
                                        },
                                        "date": {
                                            "type": "string",
                                            "format": "date",
                                            "description": "Review date"
                                        },
                                        "changes": {
                                            "type": "array",
                                            "description": "Changes made",
                                            "items": {
                                                "type": "string"
                                            }
                                        },
                                        "approval": {
                                            "type": "string",
                                            "enum": ["approved", "rejected", "pending"],
                                            "description": "Approval status"
                                        }
                                    }
                                }
                            },
                            "next_review": {
                                "type": "string",
                                "format": "date",
                                "description": "Next review date"
                            },
                            "tags": {
                                "type": "array",
                                "description": "Relevant tags",
                                "items": {
                                    "type": "string"
                                }
                            }
                        }
                    }
                }
            }
        ) 