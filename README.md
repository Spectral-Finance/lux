# Lux Cargo package management

`lux.cargo` provides typed `Cargo.toml` management plus safe delegation to
Cargo for metadata resolution and builds. It supports normal, development and
build dependencies, features, optional dependencies, version bumps, and a
content-addressed local cache.

```python
from lux.cargo import CargoManifest, Dependency, VersionManager

manifest = CargoManifest(package={"name": "demo", "version": "0.1.0", "edition": "2021"})
manifest.add_dependency(Dependency("serde", "1", features=["derive"]))
VersionManager(manifest).bump("patch")
manifest.save("Cargo.toml")
```

`CargoResolver(project).resolve(offline=True)` calls `cargo metadata`, and
`BuildPipeline(project).run("check", offline=True)` runs a reproducible check.
