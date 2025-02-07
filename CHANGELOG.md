# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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