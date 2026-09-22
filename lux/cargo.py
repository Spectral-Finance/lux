"""Small, dependency-free Cargo integration layer.

The module deliberately keeps Cargo as the source of truth: manifest edits are
typed and deterministic, while resolution/build operations delegate to Cargo.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Mapping

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python 3.10 fallback is not required by pyproject
    tomllib = None


class CargoError(RuntimeError):
    """Raised when Cargo or manifest operations fail."""


@dataclass
class Dependency:
    name: str
    version: str | None = None
    features: list[str] = field(default_factory=list)
    optional: bool = False
    default_features: bool = True
    registry: str | None = None
    git: str | None = None
    branch: str | None = None

    def value(self) -> str | dict[str, Any]:
        if not any((self.features, self.optional, not self.default_features, self.registry, self.git, self.branch)):
            return self.version or "*"
        result: dict[str, Any] = {}
        if self.version is not None: result["version"] = self.version
        if self.features: result["features"] = sorted(set(self.features))
        if self.optional: result["optional"] = True
        if not self.default_features: result["default-features"] = False
        if self.registry: result["registry"] = self.registry
        if self.git: result["git"] = self.git
        if self.branch: result["branch"] = self.branch
        return result


def _toml_value(value: Any) -> str:
    if isinstance(value, bool): return "true" if value else "false"
    if isinstance(value, str): return json.dumps(value)
    if isinstance(value, list): return "[" + ", ".join(_toml_value(v) for v in value) + "]"
    if isinstance(value, dict): return "{ " + ", ".join(f"{k} = {_toml_value(v)}" for k, v in value.items()) + " }"
    return str(value)


@dataclass
class CargoManifest:
    package: dict[str, Any] = field(default_factory=dict)
    dependencies: dict[str, Dependency] = field(default_factory=dict)
    dev_dependencies: dict[str, Dependency] = field(default_factory=dict)
    build_dependencies: dict[str, Dependency] = field(default_factory=dict)
    features: dict[str, list[str]] = field(default_factory=dict)
    workspace: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def load(cls, path: str | Path) -> "CargoManifest":
        path = Path(path)
        try: data = tomllib.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc: raise CargoError(f"Unable to read {path}: {exc}") from exc
        def deps(section: Mapping[str, Any]) -> dict[str, Dependency]:
            out = {}
            for name, raw in section.items():
                raw = {"version": raw} if isinstance(raw, str) else dict(raw)
                out[name] = Dependency(name, raw.pop("version", None), raw.pop("features", []), raw.pop("optional", False), raw.pop("default-features", True), raw.pop("registry", None), raw.pop("git", None), raw.pop("branch", None))
            return out
        return cls(data.get("package", {}), deps(data.get("dependencies", {})), deps(data.get("dev-dependencies", {})), deps(data.get("build-dependencies", {})), data.get("features", {}), data.get("workspace", {}))

    def add_dependency(self, dependency: Dependency, *, scope: str = "dependencies") -> None:
        target = {"dependencies": self.dependencies, "dev-dependencies": self.dev_dependencies, "build-dependencies": self.build_dependencies}.get(scope)
        if target is None: raise ValueError("scope must be dependencies, dev-dependencies, or build-dependencies")
        target[dependency.name] = dependency

    def remove_dependency(self, name: str, *, scope: str = "dependencies") -> bool:
        target = {"dependencies": self.dependencies, "dev-dependencies": self.dev_dependencies, "build-dependencies": self.build_dependencies}.get(scope)
        if target is None: raise ValueError("invalid dependency scope")
        return target.pop(name, None) is not None

    def render(self) -> str:
        sections: list[str] = []
        def section(name: str, values: Mapping[str, Any]) -> None:
            if values:
                sections.append("[" + name + "]\n" + "\n".join(f"{k} = {_toml_value(v.value() if isinstance(v, Dependency) else v)}" for k, v in values.items()))
        section("package", self.package); section("workspace", self.workspace)
        section("dependencies", self.dependencies); section("dev-dependencies", self.dev_dependencies); section("build-dependencies", self.build_dependencies); section("features", self.features)
        return "\n\n".join(sections) + "\n"

    def save(self, path: str | Path) -> None:
        path = Path(path); path.parent.mkdir(parents=True, exist_ok=True); path.write_text(self.render(), encoding="utf-8")


class CargoResolver:
    def __init__(self, project_dir: str | Path): self.project_dir = Path(project_dir)
    def resolve(self, *, locked: bool = False, offline: bool = False) -> dict[str, Any]:
        args = ["cargo", "metadata", "--format-version", "1", "--no-deps"]
        if locked: args.append("--locked")
        if offline: args.append("--offline")
        result = subprocess.run(args, cwd=self.project_dir, capture_output=True, text=True, check=False)
        if result.returncode: raise CargoError(result.stderr.strip() or "cargo metadata failed")
        return json.loads(result.stdout)


class BuildPipeline:
    def __init__(self, project_dir: str | Path): self.project_dir = Path(project_dir)
    def run(self, command: str = "build", *, release: bool = False, locked: bool = False, offline: bool = False) -> subprocess.CompletedProcess[str]:
        if command not in {"build", "check", "test", "clippy", "fmt"}: raise ValueError("unsupported Cargo command")
        args = ["cargo", command] + (["--release"] if release and command not in {"fmt"} else []) + (["--locked"] if locked else []) + (["--offline"] if offline else [])
        result = subprocess.run(args, cwd=self.project_dir, capture_output=True, text=True, check=False)
        if result.returncode: raise CargoError(result.stderr.strip() or f"cargo {command} failed")
        return result


class VersionManager:
    def __init__(self, manifest: CargoManifest): self.manifest = manifest
    def bump(self, part: str) -> str:
        if part not in {"major", "minor", "patch"}: raise ValueError("part must be major, minor, or patch")
        current = self.manifest.package.get("version", "0.1.0")
        match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", current)
        if not match: raise CargoError(f"Unsupported package version: {current}")
        numbers = list(map(int, match.groups())); index = {"major": 0, "minor": 1, "patch": 2}[part]; numbers[index] += 1
        for i in range(index + 1, 3): numbers[i] = 0
        self.manifest.package["version"] = ".".join(map(str, numbers)); return self.manifest.package["version"]


class PackageCache:
    """Content-addressed cache for resolved Cargo metadata or package artifacts."""
    def __init__(self, directory: str | Path): self.directory = Path(directory); self.directory.mkdir(parents=True, exist_ok=True)
    def key(self, content: bytes | str) -> str: return hashlib.sha256(content.encode() if isinstance(content, str) else content).hexdigest()
    def put(self, content: bytes, *, key: str | None = None) -> Path:
        key = key or self.key(content); target = self.directory / key; target.write_bytes(content); return target
    def get(self, key: str) -> bytes | None:
        target = self.directory / key
        return target.read_bytes() if target.is_file() else None
    def has(self, key: str) -> bool: return (self.directory / key).is_file()
