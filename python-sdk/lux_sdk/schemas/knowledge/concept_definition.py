"""
Schema for representing formal concept definitions and their relationships.
"""

from typing import Dict, List, Optional
from datetime import datetime
from lux_sdk.signals import SignalSchema

class ConceptDefinitionSchema(SignalSchema):
    """Schema for representing concept definitions in knowledge domains.
    
    This schema defines the structure for representing concepts, their semantic
    relationships, attributes, taxonomic information, and formal representations.
    
    Example:
        {
            "timestamp": "2024-04-03T15:30:00Z",
            "concept_id": "concept_20240403_153000",
            "domain_id": "domain_789",
            "concept": {
                "name": "Neural Network",
                "definition": "A computational model inspired by biological neural networks",
                "scope": "machine_learning",
                "status": "established",
                "complexity_level": "advanced",
                "context": "artificial_intelligence"
            },
            "semantic_relationships": [{
                "type": "is_a",
                "target_concept": "machine_learning_model",
                "strength": 1.0,
                "bidirectional": false,
                "description": "Neural network is a type of machine learning model",
                "evidence": [{
                    "source": "textbook_reference",
                    "reference": "Deep Learning, Goodfellow et al., 2016",
                    "confidence": 1.0
                }]
            }],
            "attributes": [{
                "name": "architecture",
                "type": "structure",
                "description": "Organization of neural layers and connections",
                "cardinality": "one_to_many",
                "constraints": {
                    "required": true,
                    "unique": false,
                    "validation_rules": ["must_have_input_layer", "must_have_output_layer"]
                },
                "examples": ["feedforward", "recurrent", "convolutional"]
            }],
            "taxonomic_information": {
                "classification": {
                    "kingdom": "artificial_intelligence",
                    "phylum": "machine_learning",
                    "class": "supervised_learning",
                    "order": "deep_learning",
                    "family": "neural_networks"
                },
                "hierarchical_path": "/AI/ML/supervised/deep_learning/neural_networks",
                "taxonomic_rank": "species",
                "related_taxa": ["svm", "decision_trees", "random_forests"]
            },
            "formal_representation": {
                "logic_type": "first_order_logic",
                "axioms": [
                    "∀x(NeuralNetwork(x) → MachineLearningModel(x))",
                    "∀x(NeuralNetwork(x) → ∃y(HasLayer(x,y) ∧ InputLayer(y)))"
                ],
                "rules": [{
                    "if": "is_neural_network",
                    "then": "has_weights_and_biases",
                    "confidence": 1.0
                }],
                "mathematical_representation": {
                    "notation": "matrix",
                    "equations": ["y = f(Wx + b)"]
                }
            },
            "usage_context": {
                "domains": ["computer_vision", "natural_language_processing", "robotics"],
                "skill_level": "advanced",
                "prerequisites": ["linear_algebra", "calculus", "probability"],
                "common_applications": [
                    "image_classification",
                    "speech_recognition",
                    "machine_translation"
                ],
                "limitations": [
                    "requires_large_datasets",
                    "computationally_intensive",
                    "black_box_nature"
                ]
            },
            "metadata": {
                "created_at": "2024-04-03T15:30:00Z",
                "created_by": "knowledge_engineer",
                "last_updated": "2024-04-03T15:30:00Z",
                "version": "1.0",
                "status": "active",
                "review_history": [{
                    "reviewer": "domain_expert",
                    "timestamp": "2024-04-02T14:00:00Z",
                    "status": "approved",
                    "comments": "Comprehensive and accurate definition"
                }],
                "references": [{
                    "type": "book",
                    "title": "Deep Learning",
                    "authors": ["Goodfellow", "Bengio", "Courville"],
                    "year": 2016,
                    "identifier": "ISBN:9780262035613"
                }],
                "tags": ["neural_networks", "deep_learning", "machine_learning"]
            }
        }
    """

    def __init__(self):
        super().__init__(
            name="concept_definition",
            version="1.0",
            description="Schema for representing concept definitions in knowledge domains",
            schema={
                "type": "object",
                "required": ["timestamp", "concept_id", "domain_id", "concept", "semantic_relationships"],
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "ISO timestamp of the concept definition"
                    },
                    "concept_id": {
                        "type": "string",
                        "description": "Unique identifier for the concept"
                    },
                    "domain_id": {
                        "type": "string",
                        "description": "Identifier of the knowledge domain"
                    },
                    "concept": {
                        "type": "object",
                        "description": "Core concept definition",
                        "required": ["name", "definition"],
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Name of the concept"
                            },
                            "definition": {
                                "type": "string",
                                "description": "Clear definition of the concept"
                            },
                            "scope": {
                                "type": "string",
                                "description": "Scope of the concept"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["proposed", "established", "deprecated", "controversial"],
                                "description": "Status of the concept"
                            },
                            "complexity_level": {
                                "type": "string",
                                "enum": ["basic", "intermediate", "advanced", "expert"],
                                "description": "Complexity level of the concept"
                            },
                            "context": {
                                "type": "string",
                                "description": "Context in which the concept is relevant"
                            }
                        }
                    },
                    "semantic_relationships": {
                        "type": "array",
                        "description": "Relationships with other concepts",
                        "items": {
                            "type": "object",
                            "required": ["type", "target_concept"],
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["is_a", "has_a", "part_of", "related_to", "opposite_of"],
                                    "description": "Type of relationship"
                                },
                                "target_concept": {
                                    "type": "string",
                                    "description": "ID of the related concept"
                                },
                                "strength": {
                                    "type": "number",
                                    "minimum": 0,
                                    "maximum": 1,
                                    "description": "Strength of the relationship"
                                },
                                "bidirectional": {
                                    "type": "boolean",
                                    "description": "Whether the relationship is bidirectional"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Description of the relationship"
                                },
                                "evidence": {
                                    "type": "array",
                                    "description": "Evidence supporting the relationship",
                                    "items": {
                                        "type": "object",
                                        "required": ["source", "confidence"],
                                        "properties": {
                                            "source": {
                                                "type": "string",
                                                "description": "Source of evidence"
                                            },
                                            "reference": {
                                                "type": "string",
                                                "description": "Reference details"
                                            },
                                            "confidence": {
                                                "type": "number",
                                                "minimum": 0,
                                                "maximum": 1,
                                                "description": "Confidence in the evidence"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    },
                    "attributes": {
                        "type": "array",
                        "description": "Defining attributes of the concept",
                        "items": {
                            "type": "object",
                            "required": ["name", "type", "description"],
                            "properties": {
                                "name": {
                                    "type": "string",
                                    "description": "Attribute name"
                                },
                                "type": {
                                    "type": "string",
                                    "description": "Attribute type"
                                },
                                "description": {
                                    "type": "string",
                                    "description": "Attribute description"
                                },
                                "cardinality": {
                                    "type": "string",
                                    "enum": ["one_to_one", "one_to_many", "many_to_one", "many_to_many"],
                                    "description": "Cardinality of the attribute"
                                },
                                "constraints": {
                                    "type": "object",
                                    "description": "Attribute constraints",
                                    "properties": {
                                        "required": {
                                            "type": "boolean",
                                            "description": "Whether the attribute is required"
                                        },
                                        "unique": {
                                            "type": "boolean",
                                            "description": "Whether the attribute must be unique"
                                        },
                                        "validation_rules": {
                                            "type": "array",
                                            "description": "Validation rules",
                                            "items": {"type": "string"}
                                        }
                                    }
                                },
                                "examples": {
                                    "type": "array",
                                    "description": "Example values",
                                    "items": {"type": "string"}
                                }
                            }
                        }
                    },
                    "taxonomic_information": {
                        "type": "object",
                        "description": "Taxonomic classification information",
                        "properties": {
                            "classification": {
                                "type": "object",
                                "description": "Taxonomic classification",
                                "additionalProperties": {"type": "string"}
                            },
                            "hierarchical_path": {
                                "type": "string",
                                "description": "Path in concept hierarchy"
                            },
                            "taxonomic_rank": {
                                "type": "string",
                                "description": "Rank in taxonomy"
                            },
                            "related_taxa": {
                                "type": "array",
                                "description": "Related taxonomic concepts",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "formal_representation": {
                        "type": "object",
                        "description": "Formal logical representation",
                        "properties": {
                            "logic_type": {
                                "type": "string",
                                "description": "Type of logic used"
                            },
                            "axioms": {
                                "type": "array",
                                "description": "Logical axioms",
                                "items": {"type": "string"}
                            },
                            "rules": {
                                "type": "array",
                                "description": "Logical rules",
                                "items": {
                                    "type": "object",
                                    "required": ["if", "then"],
                                    "properties": {
                                        "if": {
                                            "type": "string",
                                            "description": "Antecedent"
                                        },
                                        "then": {
                                            "type": "string",
                                            "description": "Consequent"
                                        },
                                        "confidence": {
                                            "type": "number",
                                            "minimum": 0,
                                            "maximum": 1,
                                            "description": "Rule confidence"
                                        }
                                    }
                                }
                            },
                            "mathematical_representation": {
                                "type": "object",
                                "description": "Mathematical representation",
                                "properties": {
                                    "notation": {
                                        "type": "string",
                                        "description": "Mathematical notation used"
                                    },
                                    "equations": {
                                        "type": "array",
                                        "description": "Mathematical equations",
                                        "items": {"type": "string"}
                                    }
                                }
                            }
                        }
                    },
                    "usage_context": {
                        "type": "object",
                        "description": "Context for concept usage",
                        "properties": {
                            "domains": {
                                "type": "array",
                                "description": "Applicable domains",
                                "items": {"type": "string"}
                            },
                            "skill_level": {
                                "type": "string",
                                "enum": ["beginner", "intermediate", "advanced", "expert"],
                                "description": "Required skill level"
                            },
                            "prerequisites": {
                                "type": "array",
                                "description": "Prerequisite concepts",
                                "items": {"type": "string"}
                            },
                            "common_applications": {
                                "type": "array",
                                "description": "Common applications",
                                "items": {"type": "string"}
                            },
                            "limitations": {
                                "type": "array",
                                "description": "Known limitations",
                                "items": {"type": "string"}
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional metadata about the concept definition",
                        "properties": {
                            "created_at": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Creation timestamp"
                            },
                            "created_by": {
                                "type": "string",
                                "description": "Creator of the concept"
                            },
                            "last_updated": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last update timestamp"
                            },
                            "version": {
                                "type": "string",
                                "description": "Concept version"
                            },
                            "status": {
                                "type": "string",
                                "enum": ["draft", "active", "deprecated", "archived"],
                                "description": "Status of the concept"
                            },
                            "review_history": {
                                "type": "array",
                                "description": "Review history",
                                "items": {
                                    "type": "object",
                                    "required": ["reviewer", "timestamp", "status"],
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
                            "references": {
                                "type": "array",
                                "description": "Reference materials",
                                "items": {
                                    "type": "object",
                                    "required": ["type", "title"],
                                    "properties": {
                                        "type": {
                                            "type": "string",
                                            "enum": ["book", "article", "paper", "website", "standard"],
                                            "description": "Reference type"
                                        },
                                        "title": {
                                            "type": "string",
                                            "description": "Reference title"
                                        },
                                        "authors": {
                                            "type": "array",
                                            "description": "Authors",
                                            "items": {"type": "string"}
                                        },
                                        "year": {
                                            "type": "integer",
                                            "description": "Publication year"
                                        },
                                        "identifier": {
                                            "type": "string",
                                            "description": "Reference identifier (e.g., DOI, ISBN)"
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