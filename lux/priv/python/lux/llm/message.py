"""Unified message and response schema shared by every provider.

Every provider normalises its native request/response payloads into the types
defined here so that callers can swap providers without touching their code.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class Role(str, Enum):
    """Conversation roles, provider-agnostic."""

    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    TOOL = "tool"


@dataclass
class ToolCall:
    """A request from the model to invoke a tool/function."""

    id: str
    name: str
    arguments: Dict[str, Any] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ToolCall":
        args = data.get("arguments", {})
        if isinstance(args, str):
            import json

            try:
                args = json.loads(args)
            except (ValueError, TypeError):
                args = {"_raw": args}
        return cls(id=data.get("id", ""), name=data.get("name", ""), arguments=args or {})


@dataclass
class Message:
    """A single conversation message.

    ``content`` is always a string for simplicity; providers that support
    multi-modal content can still be wrapped by encoding into ``content``.
    """

    role: Role
    content: str = ""
    name: Optional[str] = None
    tool_calls: List[ToolCall] = field(default_factory=list)

    def __post_init__(self) -> None:
        if isinstance(self.role, str):
            self.role = Role(self.role)

    # Convenience constructors -------------------------------------------------
    @classmethod
    def system(cls, content: str) -> "Message":
        return cls(Role.SYSTEM, content)

    @classmethod
    def user(cls, content: str) -> "Message":
        return cls(Role.USER, content)

    @classmethod
    def assistant(cls, content: str, tool_calls: Optional[List[ToolCall]] = None) -> "Message":
        return cls(Role.ASSISTANT, content, tool_calls=tool_calls or [])

    @classmethod
    def tool(cls, content: str, name: Optional[str] = None) -> "Message":
        return cls(Role.TOOL, content, name=name)

    def to_dict(self) -> Dict[str, Any]:
        data: Dict[str, Any] = {"role": self.role.value, "content": self.content}
        if self.name:
            data["name"] = self.name
        if self.tool_calls:
            data["tool_calls"] = [
                {
                    "id": tc.id,
                    "type": "function",
                    "function": {"name": tc.name, "arguments": tc.arguments},
                }
                for tc in self.tool_calls
            ]
        return data