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
                        },
                        "required": ["name", "definition"]
                    },
                    "semantic_relationships": {
                        "type": "array",
                        "description": "Relationships with other concepts",
                        "items": {
                            "type": "object",
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
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "source": {"type": "string"},
                                            "reference": {"type": "string"},
                                            "confidence": {
                                                "type": "number",
                                                "minimum": 0,
                                                "maximum": 1
                                            }
                                        },
                                        "required": ["source", "reference", "confidence"]
                                    }
                                }
                            },
                            "required": ["type", "target_concept"]
                        }
                    }
                },
                "required": ["timestamp", "concept_id", "domain_id", "concept", "semantic_relationships"]
            }
        ) 