"""
Prism architecture core for the lux monorepo's YouTube integration
(Spectral-Finance/lux issue #72 — "YouTube Prism architecture").

This module defines the *architecture* itself, independent of any concrete
prism:

  * ``Prism``        — the base class every YouTube prism subclasses. A prism is
                       a deterministic, side-effect-free unit of work: it takes a
                       ``PrismInput`` (a plain ``dict`` of params) and returns a
                       ``PrismResult``. It never performs I/O; network access is
                       the job of the ``youtube_client.YouTubeClient`` integration
                       layer, which fetches payloads and feeds them to prisms.
  * ``PrismInput``   — a thin, validating wrapper around the input ``dict`` that
                       gives prisms typed accessors (``get_str``/``get_int``/
                       ``get_list``/``get_dict``) with safe defaults, so a prism
                       body never has to guard against missing keys.
  * ``PrismResult``  — an immutable result value (``ok``/``data``/``errors``/
                       ``meta``) with ``to_dict()`` for JSON serialisation and
                       ``unwrap()`` for callers that want the raw payload.
  * ``PrismRegistry``— a name -> ``Prism`` registry so prisms can be looked up
                       and dispatched by string key (``registry.run(name, params)``),
                       mirroring how lux resolves ``Lux.Prisms.*`` modules at
                       runtime.
  * ``PrismError``   — raised when a prism is misconfigured or asked to run
                       without a registered handler.

The design goal is the lux Prism contract: **pure logic in prisms, I/O in the
client**. That keeps every decision path unit-testable offline (no sockets),
which is exactly what ``test_youtube_prisms.py`` exercises.
"""

from __future__ import annotations

from typing import Any, Callable, Dict, List, Optional


class PrismError(Exception):
    """Raised when a prism is misconfigured or dispatched incorrectly."""


class PrismInput:
    """Typed, default-safe view over a prism's input ``dict``.

    Prisms receive a single ``PrismInput`` so their bodies stay declarative:
    instead of ``params.get("maxResults", 25)`` scattered everywhere, a prism
    calls ``inp.get_int("maxResults", 25)`` and gets a coerced value with a
    guaranteed type. All accessors are pure and never raise on missing keys.
    """

    __slots__ = ("_raw",)

    def __init__(self, params: Optional[Dict[str, Any]] = None):
        if params is None:
            params = {}
        if not isinstance(params, dict):
            raise PrismError(
                f"PrismInput expects a dict, got {type(params).__name__}"
            )
        self._raw = params

    def raw(self) -> Dict[str, Any]:
        """Return the underlying dict (read-only use by the prism)."""
        return self._raw

    def has(self, key: str) -> bool:
        return key in self._raw and self._raw[key] is not None

    def get_str(self, key: str, default: str = "") -> str:
        value = self._raw.get(key)
        if isinstance(value, str):
            return value
        if value is None:
            return default
        return str(value)

    def get_int(self, key: str, default: int = 0) -> int:
        value = self._raw.get(key)
        if isinstance(value, bool):
            return int(value)
        if isinstance(value, int):
            return value
        if isinstance(value, float):
            return int(value)
        if isinstance(value, str):
            try:
                return int(value.strip())
            except (ValueError, TypeError):
                return default
        return default

    def get_float(self, key: str, default: float = 0.0) -> float:
        value = self._raw.get(key)
        if isinstance(value, bool):
            return float(value)
        if isinstance(value, (int, float)):
            return float(value)
        if isinstance(value, str):
            try:
                return float(value.strip())
            except (ValueError, TypeError):
                return default
        return default

    def get_list(self, key: str, default: Optional[List[Any]] = None) -> List[Any]:
        value = self._raw.get(key)
        if isinstance(value, list):
            return value
        return list(default) if default is not None else []

    def get_dict(self, key: str, default: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        value = self._raw.get(key)
        if isinstance(value, dict):
            return value
        return dict(default) if default is not None else {}


class PrismResult:
    """Immutable result value returned by every :class:`Prism`."""

    __slots__ = ("ok", "data", "errors", "meta")

    def __init__(
        self,
        data: Optional[Dict[str, Any]] = None,
        *,
        ok: bool = True,
        errors: Optional[List[str]] = None,
        meta: Optional[Dict[str, Any]] = None,
    ):
        self.ok = ok
        self.data = data if data is not None else {}
        self.errors = errors if errors is not None else []
        self.meta = meta if meta is not None else {}

    def to_dict(self) -> Dict[str, Any]:
        """Serialise to a plain dict for JSON / API responses."""
        out: Dict[str, Any] = {"ok": self.ok, "data": self.data}
        if self.errors:
            out["errors"] = list(self.errors)
        if self.meta:
            out["meta"] = dict(self.meta)
        return out

    def unwrap(self) -> Dict[str, Any]:
        """Return the raw ``data`` payload (raises if the result is not ok)."""
        if not self.ok:
            raise PrismError(f"prism result is not ok: {self.errors}")
        return self.data

    def __repr__(self) -> str:  # pragma: no cover - debug aid
        return f"PrismResult(ok={self.ok!r}, data={self.data!r})"


class Prism:
    """Base class for every YouTube prism.

    Subclasses set a class-level ``name`` and implement :meth:`run`. The base
    class provides:

      * ``__call__`` — accept a raw ``dict`` (or ``PrismInput``) and return a
        ``PrismResult`` (so a prism instance is a drop-in callable).
      * ``validate`` — an optional hook subclasses override to reject bad input
        before :meth:`run` executes.

    Prisms are deterministic and side-effect free: identical input always yields
    an identical ``PrismResult`` and no network/socket/file access happens.
    """

    #: Registry key for the prism (subclasses override).
    name: str = "base"

    def run(self, inp: PrismInput) -> PrismResult:  # pragma: no cover - abstract
        raise NotImplementedError

    def validate(self, inp: PrismInput) -> None:
        """Override to raise ``PrismError`` on invalid input. Default: no-op."""
        return None

    def __call__(self, params: Optional[Dict[str, Any]] = None) -> PrismResult:
        inp = params if isinstance(params, PrismInput) else PrismInput(params)
        self.validate(inp)
        return self.run(inp)


class PrismRegistry:
    """Name -> :class:`Prism` registry with string-key dispatch.

    Mirrors how lux resolves ``Lux.Prisms.<Name>`` modules at runtime: callers
    register prism instances (or classes) once, then dispatch by name with
    ``registry.run("channel_stats", params)``.
    """

    def __init__(self) -> None:
        self._prisms: Dict[str, Prism] = {}

    def register(self, prism: Prism) -> "PrismRegistry":
        if not isinstance(prism, Prism):
            raise PrismError(
                f"can only register Prism instances, got {type(prism).__name__}"
            )
        if not prism.name:
            raise PrismError("prism must define a non-empty class-level `name`")
        self._prisms[prism.name] = prism
        return self

    def get(self, name: str) -> Prism:
        try:
            return self._prisms[name]
        except KeyError:
            raise PrismError(
                f"no prism registered under name {name!r}; "
                f"known: {sorted(self._prisms)}"
            )

    def has(self, name: str) -> bool:
        return name in self._prisms

    def names(self) -> List[str]:
        return sorted(self._prisms)

    def run(self, name: str, params: Optional[Dict[str, Any]] = None) -> PrismResult:
        """Dispatch to a registered prism by name and return its ``PrismResult``."""
        return self.get(name)(params)

    def __len__(self) -> int:
        return len(self._prisms)

    def __contains__(self, name: str) -> bool:
        return name in self._prisms