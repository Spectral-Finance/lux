"""
Knowledge Management Schemas

This module provides schemas for knowledge representation and management,
including knowledge graphs, ontologies, fact management, and expertise tracking.
"""

from .knowledge_graph import KnowledgeGraphSchema
from .ontology_mapping import OntologyMappingSchema
from .fact_assertion import FactAssertionSchema
from .concept_definition import ConceptDefinitionSchema
from .knowledge_validation import KnowledgeValidationSchema
from .information_request import InformationRequestSchema
from .source_citation import SourceCitationSchema
from .knowledge_gap import KnowledgeGapSchema
from .expertise_level import ExpertiseLevelSchema
from .domain_transfer import DomainTransferSchema

__all__ = [
    'KnowledgeGraphSchema',
    'OntologyMappingSchema',
    'FactAssertionSchema',
    'ConceptDefinitionSchema',
    'KnowledgeValidationSchema',
    'InformationRequestSchema',
    'SourceCitationSchema',
    'KnowledgeGapSchema',
    'ExpertiseLevelSchema',
    'DomainTransferSchema'
] 