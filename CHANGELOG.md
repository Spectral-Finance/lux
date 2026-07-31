# Changelog

All notable changes to Lux are documented here.

## [Unreleased]

### Added
- Agent lifecycle hooks (created, started, completed, failed)
- Signal processing pipeline with configurable filters
- WebSocket support for real-time agent monitoring
- Rate limiting middleware
- SDK packages for Python and TypeScript

### Changed
- Upgraded to Node.js 20 LTS
- Migrated config from JSON to YAML
- Improved error handling with structured error codes

### Deprecated
- Legacy REST API v0 (removal in v2.0.0)
- `agent.execute()` method (use `agent.run()` instead)

### Fixed
- Race condition in parallel agent execution
- Memory leak in long-running signal processors
- Incorrect agent status reporting during startup

### Security
- Added token-based authentication
- Rate limiting per API key
- Input sanitization for all user-provided data

## [1.0.0] - 2025-01-15

### Added
- Initial release
- REST API for agent management
- Core agent engine with task scheduling
- Signal processing framework
- SQLite-based persistence layer
- CLI tool for local development
- Docker deployment support
- Basic monitoring dashboard

### Known Issues
- Agent status may desync under high load
- No authentication (added in 1.1.0)
- Limited error recovery for failed agents
