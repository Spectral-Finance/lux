# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Lux Rust Testing Framework** under `priv/rust/`:
  - New Cargo workspace with the `lux_core` crate
  - `lux_core::testing` module providing `Recorder<T>`,
    `assert_eq_with_context`, `assert_runs_within`, and the canonical
    `sample_signal` fixture — all dependency-free so contributors only
    need the standard Rust toolchain
  - `lux_core::signal::Signal` — Rust counterpart of `Lux.Signal`
  - Integration smoke tests under `priv/rust/lux_core/tests/`
- New mix task `mix rust.test` that shells out to `cargo test --workspace`
  and forwards arbitrary Cargo arguments (e.g. `--release`, test name
  filters). Provides actionable error messages when Cargo is missing or
  the `priv/rust/` workspace is absent.
- Elixir-side unit tests for `mix rust.test` under
  `test/unit/mix/tasks/rust_test_test.exs` covering: missing Cargo,
  missing workspace, default argument forwarding, custom argument
  forwarding, non-zero exit handling, and a workspace-existence sanity
  check.
- Documentation updates in `guides/language_support.md`,
  `guides/testing.md`, `guides/contributing.md` and a new
  `priv/rust/README.md` describing layout, prerequisites and the
  contributor workflow.
- `make test` now also runs `mix rust.test`.

## [0.4.0] - 2025-02-20

### Added
- Company management system with execution engine and objectives
- Role-based agent management for companies
- New DSL for company and objective definitions
- Artifact store for company execution outputs
- Task tracking and objective process management
- Local company hub implementation
- Enhanced agent base functionality
- New guides for company management and role management
- Objective and task signal schemas
- Company-specific signal handlers for agents

### Changed
- Updated agent hub implementation for company support
- Enhanced signal router for company-related signals
- Improved configuration system
- Updated OpenAI LLM integration
- Enhanced documentation across all guides
- Refactored agent base implementation

### Fixed
- Various documentation improvements and corrections

## [0.2.0] - 2025-02-05

### Added
- Support for multiple named AgentHub instances
- Improved agent lifecycle management with proper process monitoring
- Enhanced test coverage for agent collaboration scenarios
- Support for running integration tests asynchronously

### Changed
- Renamed `Lux.Agent.Registry` to `Lux.AgentHub` for better clarity
- Updated agent registration to support multiple hub instances
- Improved agent status tracking and offline detection
- Enhanced test reliability with proper process cleanup

### Fixed
- Agent status not updating correctly when processes terminate
- Race conditions in agent status management tests
- Process monitoring in multi-hub scenarios

## [0.1.0] - 2025-01-16

### Added
- Initial release of Lux framework
- Basic agent infrastructure with configurable components
- Agent supervision and lifecycle management
- Communication foundation with signal system
- Basic collaboration protocols
- Agent discovery and capability advertisement
- Status tracking for agents
- Integration with OpenAI's GPT models 