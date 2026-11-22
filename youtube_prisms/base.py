"""
Core Prism architecture for the Lux YouTube content-intelligence prisms
(Spectral-Finance/lux issue #77).

This module mirrors the contract of the Elixir ``Lux.Prism`` behaviour used
throughout the lux monorepo: every prism is a *named*, *described* unit of work
that declares an ``input_schema`` and an ``output_schema`` and exposes a
``handler`` that turns a validated input mapping into a structured result.

The design keeps the monorepo's central invariant intact:

    **Prisms are pure. All I/O lives in the client.**

A prism never opens a socket, never reads the clock, and never mutates global
state. Given the same input mapping it always returns the same ``PrismResult``.
That makes every prism a deterministic, side-effect-free unit that can be unit
tested offline -- callers fetch raw YouTube Data API v3 payloads through their
client and hand the parsed ``dict`` to a prism.

Public surface
--------------
``Prism``          -- base class; subclass it and implement ``handler``.
``PrismInput``     -- typed, default-safe view over the input mapping.
``PrismResult``    -- immutable ``{ok, data, errors, meta}`` value object.
``PrismRegistry``  -- name -> Prism dispatch, mirroring ``Lux.Prisms.<Name>``.
``build_registry`` -- a registry pre-loaded with every concrete YouTube prism.
"""

from __future__ import annotations

from typing import Any, Callable, Dict, List, Mapping, Optional

__all__ = [
    "PrismError",
    "PrismInput",
    "PrismResult",
    "Prism",
    "PrismRegistry",
    "build_registry",
]


class PrismError(ValueError):
    """Raised when a prism receives input that violates its ``input_schema``."""


# ---------------------------------------------------------------------------
# Input / result value objects
# ---------------------------------------------------------------------------
class PrismInput:
    """A typed, default-safe view over a prism's input mapping.

    Prism bodies read their parameters through these accessors instead of
    guarding every ``dict.get`` against missing keys or wrong types. This keeps
    the handler logic focused on the actual computation.
    """

    __slots__ = ("_raw",)

    def __init__(self, raw: Optional[Mapping[str, Any]] = None) -> None:
        if raw is None:
            raw = {}
        if not isinstance(raw, Mapping):
            raise PrismError("PrismInput expects a mapping, got %r" % (type(raw),))
        self._raw: Dict[str, Any] = dict(raw)

    def get_str(self, key: str, default: str = "") -> str:
        value = self._raw.get(key)
        if value is None:
            return default
        if isinstance(value, str):
            return value
        return str(value)

    def get_int(self, key: str, default: int = 0) -> int:
        value = self._raw.get(key)
        if value is None or value == "":
            return default
        try:
            return int(value)
        except (TypeError, ValueError):
            try:
                return int(float(value))
            except (TypeError, ValueError):
                return default

    def get_float(self, key: str, default: float = 0.0) -> float:
        value = self._raw.get(key)
        if value is None or value == "":
            return default
        try:
            return float(value)
        except (TypeError, ValueError):
            return default

    def get_list(self, key: str, default: Optional[List[Any]] = None) -> List[Any]:
        value = self._raw.get(key)
        if value is None:
            return list(default) if default is not None else []
        if isinstance(value, (list, tuple)):
            return list(value)
        return [value]

    def get_dict(self, key: str, default: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        value = self._raw.get(key)
        if value is None:
            return dict(default) if default is not None else {}
        if isinstance(value, Mapping):
            return dict(value)
        return dict(default) if default is not None else {}

    def has(self, key: str) -> bool:
        return key in self._raw and self._raw[key] is not None

    def as_dict(self) -> Dict[str, Any]:
        return dict(self._raw)

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return "PrismInput(%r)" % (self._raw,)


class PrismResult:
    """Immutable ``{ok, data, errors, meta}`` value object.

    Mirrors the ``{:ok, result}`` / ``{:error, reason}`` tagged tuples the
    Elixir prisms return, but as a single structured value that is easy to
    serialise to JSON for an agent to consume.
    """

    __slots__ = ("ok", "data", "errors", "meta")

    def __init__(
        self,
        ok: bool,
        data: Optional[Dict[str, Any]] = None,
        errors: Optional[List[str]] = None,
        meta: Optional[Dict[str, Any]] = None,
    ) -> None:
        self.ok = bool(ok)
        self.data: Dict[str, Any] = dict(data) if data else {}
        self.errors: List[str] = list(errors) if errors else []
        self.meta: Dict[str, Any] = dict(meta) if meta else {}

    @classmethod
    def success(
        cls, data: Optional[Dict[str, Any]] = None, **meta: Any
    ) -> "PrismResult":
        return cls(True, data=data, meta=meta)

    @classmethod
    def failure(
        cls, errors: Any, data: Optional[Dict[str, Any]] = None, **meta: Any
    ) -> "PrismResult":
        if isinstance(errors, str):
            errors = [errors]
        return cls(False, data=data, errors=list(errors), meta=meta)

    def unwrap(self) -> Dict[str, Any]:
        """Return ``data`` when ok, otherwise raise ``PrismError``."""
        if not self.ok:
            raise PrismError("; ".join(self.errors) or "prism failed")
        return self.data

    def to_dict(self) -> Dict[str, Any]:
        return {
            "ok": self.ok,
            "data": self.data,
            "errors": self.errors,
            "meta": self.meta,
        }

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return "PrismResult(ok=%r, data=%r, errors=%r)" % (
            self.ok,
            self.data,
            self.errors,
        )


# ---------------------------------------------------------------------------
# Lightweight JSON-schema (subset) validation
# ---------------------------------------------------------------------------
_JSON_TYPES: Dict[str, Any] = {
    "object": Mapping,
    "array": (list, tuple),
    "string": str,
    "integer": int,
    "number": (int, float),
    "boolean": bool,
}


def _validate_against_schema(
    schema: Optional[Mapping[str, Any]], payload: Mapping[str, Any]
) -> List[str]:
    """Validate ``payload`` against a tiny JSON-schema subset.

    Supports ``type`` (object), ``properties`` (per-key type), and
    ``required``. Unknown keywords are ignored so richer schemas degrade
    gracefully. Returns a list of human-readable error strings (empty == ok).
    """
    if not schema:
        return []
    errors: List[str] = []

    expected = schema.get("type")
    if expected == "object" and not isinstance(payload, Mapping):
        errors.append("expected object, got %r" % (type(payload).__name__,))
        return errors

    properties = schema.get("properties") or {}
    for key in schema.get("required", []) or []:
        if key not in payload or payload[key] is None:
            errors.append("missing required property %r" % (key,))

    for key, subschema in properties.items():
        if key not in payload or payload[key] is None:
            continue
        value = payload[key]
        stype = (subschema or {}).get("type")
        if stype and stype in _JSON_TYPES:
            # bool is a subclass of int in Python; keep integer/number honest.
            if stype in ("integer", "number") and isinstance(value, bool):
                errors.append("property %r must be %s" % (key, stype))
                continue
            if not isinstance(value, _JSON_TYPES[stype]):
                errors.append(
                    "property %r must be %s, got %s"
                    % (key, stype, type(value).__name__)
                )
    return errors


# ---------------------------------------------------------------------------
# Prism base class
# ---------------------------------------------------------------------------
class Prism:
    """Base class for every YouTube content-intelligence prism.

    Subclasses set the class attributes ``name``, ``description``,
    ``input_schema`` and ``output_schema`` (mirroring ``use Lux.Prism``) and
    implement :meth:`handler`. Calling the prism validates the input against
    ``input_schema`` and wraps the handler's return value in a
    :class:`PrismResult`.
    """

    #: Human-readable prism name (mirrors ``name:`` in ``use Lux.Prism``).
    name: str = "Prism"
    #: One-line description of what the prism computes.
    description: str = ""
    #: JSON-schema subset describing accepted input.
    input_schema: Dict[str, Any] = {}
    #: JSON-schema subset describing the produced output.
    output_schema: Dict[str, Any] = {}

    def handler(self, params: PrismInput) -> Dict[str, Any]:  # pragma: no cover
        raise NotImplementedError

    def validate(self, params: PrismInput) -> List[str]:
        """Hook for subclasses to add semantic validation beyond the schema."""
        return []

    def run(self, params: Optional[Mapping[str, Any]] = None) -> PrismResult:
        """Validate ``params`` and execute :meth:`handler`, returning a result."""
        try:
            inp = params if isinstance(params, PrismInput) else PrismInput(params)
        except PrismError as exc:
            return PrismResult.failure([str(exc)])

        raw = inp.as_dict()
        errors = _validate_against_schema(self.input_schema, raw)
        if not errors:
            try:
                errors = self.validate(inp)
            except PrismError as exc:  # pragma: no cover - defensive
                errors = [str(exc)]

        if errors:
            return PrismResult.failure(errors, meta={"prism": self.name})

        try:
            data = self.handler(inp)
        except PrismError as exc:
            return PrismResult.failure([str(exc)], meta={"prism": self.name})
        except Exception as exc:  # pragma: no cover - defensive
            return PrismResult.failure(
                ["%s: %s" % (type(exc).__name__, exc)], meta={"prism": self.name}
            )

        if not isinstance(data, Mapping):
            return PrismResult.failure(
                ["handler must return a mapping, got %s" % type(data).__name__],
                meta={"prism": self.name},
            )
        return PrismResult.success(dict(data), prism=self.name)

    # ``__call__`` lets a prism instance be used as a drop-in callable, matching
    # the way Lux agents invoke ``Prism.handler(input, ctx)``.
    __call__ = run

    def spec(self) -> Dict[str, Any]:
        """Return the prism's self-description (name/description/schemas)."""
        return {
            "name": self.name,
            "description": self.description,
            "input_schema": self.input_schema,
            "output_schema": self.output_schema,
        }


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------
class PrismRegistry:
    """Name -> :class:`Prism` dispatch table.

    Mirrors how lux resolves ``Lux.Prisms.<Name>`` modules at runtime: a caller
    asks the registry for a prism by name and runs it against a params mapping.
    """

    def __init__(self) -> None:
        self._prisms: Dict[str, Prism] = {}

    def register(self, prism: Prism, name: Optional[str] = None) -> "PrismRegistry":
        key = name or prism.name
        self._prisms[key] = prism
        return self

    def get(self, name: str) -> Prism:
        try:
            return self._prisms[name]
        except KeyError:
            raise PrismError("no prism registered under %r" % (name,))

    def has(self, name: str) -> bool:
        return name in self._prisms

    def names(self) -> List[str]:
        return sorted(self._prisms)

    def run(self, name: str, params: Optional[Mapping[str, Any]] = None) -> PrismResult:
        return self.get(name).run(params)

    def specs(self) -> List[Dict[str, Any]]:
        return [self._prisms[n].spec() for n in self.names()]

    def __contains__(self, name: str) -> bool:  # pragma: no cover - trivial
        return name in self._prisms

    def __len__(self) -> int:  # pragma: no cover - trivial
        return len(self._prisms)


def build_registry() -> PrismRegistry:
    """Return a :class:`PrismRegistry` pre-loaded with every YouTube prism.

    Imports are local to avoid a circular import at module load time.
    """
    from .channel import ChannelBenchmarkPrism, ChannelGrowthPrism
    from .discovery import ContentGapPrism, TrendingTopicsPrism
    from .engagement import AudienceRetentionPrism, EngagementTrendPrism
    from .monetization import RevenueEstimatePrism
    from .playlist import PlaylistOverviewPrism, PlaylistStatsPrism
    from .primitives import (
        ChannelKeywordsPrism,
        ChannelListPrism,
        ChannelResourcePrism,
        ChannelStatsPrism,
        EngagementComparePrism,
        EngagementPrism,
        KeywordPrism,
        PlaylistItemsPrism,
        PlaylistResourcePrism,
        SearchResultPrism,
        UploadsPrism,
        VideoListPrism,
        VideoResourcePrism,
        VideoStatsPrism,
    )
    from .seo import SeoAuditPrism
    from .video import VideoMetadataPrism, VideoPerformancePrism

    registry = PrismRegistry()
    for prism_cls in (
        # Intelligence prisms (issue #77 core)
        VideoPerformancePrism,
        VideoMetadataPrism,
        ChannelGrowthPrism,
        ChannelBenchmarkPrism,
        TrendingTopicsPrism,
        ContentGapPrism,
        PlaylistStatsPrism,
        PlaylistOverviewPrism,
        EngagementTrendPrism,
        AudienceRetentionPrism,
        RevenueEstimatePrism,
        SeoAuditPrism,
        # Parsing-primitive prisms (resource normalisation layer)
        ChannelStatsPrism,
        ChannelResourcePrism,
        SearchResultPrism,
        ChannelListPrism,
        VideoStatsPrism,
        VideoResourcePrism,
        VideoListPrism,
        PlaylistResourcePrism,
        PlaylistItemsPrism,
        UploadsPrism,
        EngagementPrism,
        EngagementComparePrism,
        KeywordPrism,
        ChannelKeywordsPrism,
    ):
        registry.register(prism_cls())
    return registry