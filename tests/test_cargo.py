import json
import subprocess
from pathlib import Path
import pytest
from lux.cargo import *

def test_manifest_round_trip_and_scopes(tmp_path):
    p = tmp_path / "Cargo.toml"
    m = CargoManifest(package={"name":"demo", "version":"0.1.0", "edition":"2021"})
    m.add_dependency(Dependency("serde", "1", features=["derive"]))
    m.add_dependency(Dependency("anyhow", "1"), scope="dev-dependencies")
    m.add_dependency(Dependency("cc", "1"), scope="build-dependencies")
    m.save(p); loaded = CargoManifest.load(p)
    assert loaded.dependencies["serde"].features == ["derive"]
    assert loaded.dev_dependencies["anyhow"].version == "1"
    assert loaded.remove_dependency("cc", scope="build-dependencies")

def test_dependency_options_and_invalid_scope():
    d = Dependency("foo", optional=True, default_features=False, git="https://example.invalid/foo", branch="main")
    assert d.value()["default-features"] is False
    with pytest.raises(ValueError): CargoManifest().add_dependency(d, scope="bad")

def test_version_bumps_and_invalid_version():
    m = CargoManifest(package={"version":"1.2.3"}); v = VersionManager(m)
    assert v.bump("minor") == "1.3.0"
    with pytest.raises(ValueError): v.bump("x")
    m.package["version"] = "next"
    with pytest.raises(CargoError):
        v.bump("patch")

def test_cache(tmp_path):
    c = PackageCache(tmp_path); key = c.key("abc"); assert not c.has(key)
    c.put(b"abc", key=key); assert c.get(key) == b"abc"; assert c.has(key)

def test_resolver_and_build_commands(tmp_path, monkeypatch):
    calls = []
    def fake_run(args, **kwargs):
        calls.append((args, kwargs)); return subprocess.CompletedProcess(args, 0, '{"packages":[]}', '')
    monkeypatch.setattr(subprocess, "run", fake_run)
    assert CargoResolver(tmp_path).resolve(locked=True, offline=True) == {"packages": []}
    BuildPipeline(tmp_path).run("check", locked=True, offline=True)
    assert calls[0][0] == ["cargo", "metadata", "--format-version", "1", "--no-deps", "--locked", "--offline"]
    assert calls[1][0] == ["cargo", "check", "--locked", "--offline"]

def test_command_errors_and_invalid_command(tmp_path, monkeypatch):
    monkeypatch.setattr(subprocess, "run", lambda *a, **k: subprocess.CompletedProcess([], 1, "", "broken"))
    with pytest.raises(CargoError, match="broken"): CargoResolver(tmp_path).resolve()
    with pytest.raises(ValueError): BuildPipeline(tmp_path).run("publish")
