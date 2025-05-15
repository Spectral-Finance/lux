"""Tests that all schema modules can be imported successfully."""

import pytest
from typing import List, Tuple

# Cognitive Schemas
COGNITIVE_SCHEMAS = [
    'ReasoningChainSchema',
    'MemoryRecallSchema',
    'DecisionMatrixSchema',
    'HypothesisFormulationSchema',
    'BeliefUpdateSchema',
    'CognitiveStateSchema',
    'AttentionFocusSchema',
    'LearningProgressSchema',
    'InferenceResultSchema',
    'MetacognitionReportSchema',
    'CreativityOutputSchema',
    'ProblemDecompositionSchema'
]

# Emotional Schemas
EMOTIONAL_SCHEMAS = [
    'EmotionalStateSchema',
    'EmpathyResponseSchema',
    'SentimentAnalysisSchema',
    'MoodRegulationSchema',
    'SocialAwarenessSchema',
    'EmotionalTriggerSchema',
    'RelationshipDynamicsSchema',
    'EmotionalResonanceSchema',
    'ConflictResolutionSchema',
    'EmotionalSupportSchema'
]

# Knowledge Schemas
KNOWLEDGE_SCHEMAS = [
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

# Natural Language Schemas
NATURAL_LANGUAGE_SCHEMAS = [
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

# Task Schemas
TASK_SCHEMAS = [
    'TaskDefinitionSchema',
    'ExecutionPlanSchema',
    'ResourceRequirementSchema',
    'ProgressUpdateSchema',
    'QualityMetricSchema',
    'TimeEstimateSchema',
    'DependencyChainSchema',
    'ConstraintDefinitionSchema',
    'OptimizationGoalSchema',
    'ErrorHandlingSchema',
    'TaskPrioritySchema'
]

# Collaboration Schemas
COLLABORATION_SCHEMAS = [
    'TeamFormationSchema',
    'RoleAssignmentSchema',
    'ConsensusBuildingSchema',
    'ResourceSharingSchema',
    'ConflictMediationSchema',
    'FeedbackLoopSchema',
    'CoordinationProtocolSchema',
    'ResponsibilityMatrixSchema',
    'TeamDynamicsSchema'
]

# Data Processing Schemas
DATA_SCHEMAS = [
    'DataSchemaSchema',
    'DataCollectionSchema',
    'DataTransformationSchema'
]

# Scientific Research Schemas
SCIENTIFIC_SCHEMAS = [
    'ExperimentDesignSchema',
    'HypothesisTestSchema',
    'DataCollectionSchema',
    'StatisticalAnalysisSchema'
]

# Creative Arts Schemas
CREATIVE_SCHEMAS = [
    'ArtisticConceptSchema',
    'DesignSpecificationSchema',
    'StyleGuideSchema',
    'ColorPaletteSchema',
    'CompositionLayoutSchema',
    'NarrativeStructureSchema',
    'CharacterDevelopmentSchema',
    'SceneDescriptionSchema',
    'MusicalScoreSchema',
    'VisualReferenceSchema',
    'ArtisticFeedbackSchema'
]

# Business Process Schemas
BUSINESS_SCHEMAS = [
    'MarketAnalysisSchema',
    'FinancialReportSchema',
    'ProjectProposalSchema',
    'RiskAssessmentSchema',
    'StrategyPlanSchema',
    'CustomerFeedbackSchema',
    'ResourceAllocationSchema',
    'PerformanceMetricSchema'
]

# Ethical Reasoning Schemas
ETHICAL_SCHEMAS = [
    'EthicalDilemmaSchema',
    'ValueAlignmentSchema',
    'MoralJudgmentSchema',
    'StakeholderImpactSchema',
    'EthicalPrincipleSchema',
    'BiasDetectionSchema',
    'FairnessMetricSchema',
    'AccountabilityFrameSchema',
    'TransparencyReportSchema',
    'EthicalJustificationSchema'
]

# System Operations Schemas
SYSTEM_SCHEMAS = [
    'SystemStateSchema',
    'PerformanceMetricsSchema',
    'ErrorLogSchema',
    'SecurityAlertSchema',
    'ResourceUsageSchema',
    'ConfigurationUpdateSchema'
]

# Environmental Awareness Schemas
ENVIRONMENTAL_SCHEMAS = [
    'EnvironmentalStateSchema',
    'SensorDataSchema',
    'SpatialRelationSchema',
    'ObjectRecognitionSchema',
    'EventDetectionSchema'
]

# Healthcare Schemas
HEALTHCARE_SCHEMAS = [
    'MedicalDiagnosisSchema',
    'TreatmentPlanSchema',
    'PatientHistorySchema',
    'VitalSignsSchema',
    'MedicationScheduleSchema',
    'SymptomReportSchema'
]

# Education & Training Schemas
EDUCATION_SCHEMAS = [
    'LearningObjectiveSchema',
    'CurriculumDesignSchema',
    'AssessmentCriteriaSchema',
    'ProgressReportSchema',
    'FeedbackReportSchema',
    'SkillEvaluationSchema',
    'LearningResourceSchema',
    'CompetencyLevelSchema',
]

WEB3_SCHEMAS = [
    'TransactionSchema',
    'SmartContractSchema',
    'NFTMetadataSchema',
    'WalletStateSchema',
    'DeFiPositionSchema'
]

# All schema categories with their module paths
SCHEMA_CATEGORIES: List[Tuple[str, str, List[str]]] = [
    ('Cognitive', 'lux_sdk.schemas.cognitive', COGNITIVE_SCHEMAS),
    ('Emotional', 'lux_sdk.schemas.emotional', EMOTIONAL_SCHEMAS),
    ('Knowledge', 'lux_sdk.schemas.knowledge', KNOWLEDGE_SCHEMAS),
    ('Natural Language', 'lux_sdk.schemas.natural_language', NATURAL_LANGUAGE_SCHEMAS),
    ('Task', 'lux_sdk.schemas.task', TASK_SCHEMAS),
    ('Collaboration', 'lux_sdk.schemas.collaboration', COLLABORATION_SCHEMAS),
    ('Data', 'lux_sdk.schemas.data', DATA_SCHEMAS),
    ('Scientific', 'lux_sdk.schemas.scientific', SCIENTIFIC_SCHEMAS),
    ('Creative', 'lux_sdk.schemas.creative', CREATIVE_SCHEMAS),
    ('Business', 'lux_sdk.schemas.business', BUSINESS_SCHEMAS),
    ('Ethical', 'lux_sdk.schemas.ethical', ETHICAL_SCHEMAS),
    ('System', 'lux_sdk.schemas.system', SYSTEM_SCHEMAS),
    ('Environmental', 'lux_sdk.schemas.environmental', ENVIRONMENTAL_SCHEMAS),
    ('Healthcare', 'lux_sdk.schemas.healthcare', HEALTHCARE_SCHEMAS),
    ('Education', 'lux_sdk.schemas.education', EDUCATION_SCHEMAS),
    ('Web3', 'lux_sdk.schemas.web3', WEB3_SCHEMAS)
]

@pytest.mark.parametrize("category,module_path,schemas", SCHEMA_CATEGORIES)
def test_schema_imports(category: str, module_path: str, schemas: List[str]):
    """Test that all schemas in a category can be imported."""
    try:
        module = __import__(module_path, fromlist=schemas)
        for schema in schemas:
            try:
                getattr(module, schema)
            except AttributeError:
                pytest.fail(f"Schema {schema} not found in {category} category")
    except ImportError as e:
        pytest.fail(f"Failed to import {category} schemas: {str(e)}") 