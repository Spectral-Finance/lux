"""
Collaboration Schemas

This module provides schemas for collaborative processes and team interactions,
including team formation, role management, and coordination protocols.
"""

from .team_formation import TeamFormationSchema
from .role_assignment import RoleAssignmentSchema
from .consensus_building import ConsensusBuildingSchema
from .resource_sharing import ResourceSharingSchema
from .conflict_mediation import ConflictMediationSchema
from .feedback_loop import FeedbackLoopSchema
from .coordination_protocol import CoordinationProtocolSchema
from .responsibility_matrix import ResponsibilityMatrixSchema
from .team_dynamics import TeamDynamicsSchema
from .collaborative_goal import CollaborativeGoalSchema

__all__ = [
    'TeamFormationSchema',
    'RoleAssignmentSchema',
    'ConsensusBuildingSchema',
    'ResourceSharingSchema',
    'ConflictMediationSchema',
    'FeedbackLoopSchema',
    'CoordinationProtocolSchema',
    'ResponsibilityMatrixSchema',
    'TeamDynamicsSchema',
    'CollaborativeGoalSchema'
] 