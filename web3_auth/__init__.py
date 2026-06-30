"""
Spectral-Finance/lux: Web3 Authentication and Authorization Framework

This module provides EIP-4361 compliant authentication, multi-signature support,
and role-based access control for the Lux platform.
"""

from .auth import (
    parse_eip4361_message,
    verify_signature,
    check_permissions,
    generate_session_token,
    validate_multisig,
    AuditLogger
)

__version__ = "1.0.0"
__all__ = [
    "parse_eip4361_message",
    "verify_signature",
    "check_permissions",
    "generate_session_token",
    "validate_multisig",
    "AuditLogger"
]