"""
Natural Language Processing Schemas

This module provides schemas for natural language processing tasks,
including text analysis, dialogue management, language generation, and translation.
"""

from .text_analysis import TextAnalysisSchema
from .dialogue_state import DialogueStateSchema
from .language_generation import LanguageGenerationSchema
from .translation_request import TranslationRequestSchema
from .syntax_tree import SyntaxTreeSchema
from .semantic_frame import SemanticFrameSchema
from .pragmatic_context import PragmaticContextSchema
from .discourse_marker import DiscourseMarkerSchema
from .style_guide import StyleGuideSchema
from .clarification import ClarificationSchema
from .paraphrase import ParaphraseSchema

__all__ = [
    'TextAnalysisSchema',
    'DialogueStateSchema',
    'LanguageGenerationSchema',
    'TranslationRequestSchema',
    'SyntaxTreeSchema',
    'SemanticFrameSchema',
    'PragmaticContextSchema',
    'DiscourseMarkerSchema',
    'StyleGuideSchema',
    'ClarificationSchema',
    'ParaphraseSchema'
] 