# Lux CLI

[![Hex.pm](https://img.shields.io/hexpm/v/lux_cli.svg)](https://hex.pm/packages/lux_cli)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lux_cli)

> ⚠️ **Note**: Lux CLI is currently under heavy development and should be considered pre-alpha software. The API and architecture are subject to significant changes. We welcome feedback and contributions.

Lux CLI provides a command-line interface for the Lux framework, allowing users to create, manage, and monitor agent workflows from the terminal. It offers a unified experience for working with Lux components and supports various deployment modes.

## Features

### 1. Project Management 📁

Create and manage Lux projects:
- Initialize new projects with templates
- Generate agents, prisms, and beams
- Validate project structure and configurations
- Run tests and checks

### 2. Deployment Options 🚀

Run Lux in different modes:
- Core mode (no web server)
- Web mode (with web interface)
- Daemon mode (background process with webhooks)

### 3. Monitoring and Debugging 🔍

Inspect and troubleshoot your agent systems:
- View logs and metrics
- Inspect agent state
- Trace signal flows
- Profile performance

## Installation

### From Hex

```bash
mix escript.install hex lux_cli
```

### From Source

```bash
git clone https://github.com/Spectral-Finance/lux.git
cd lux/cli
mix deps.get
mix escript.build
```

## Usage

### Starting Lux

```bash
# Start Lux in core mode (no web server)
lux start

# Start Lux with web server
lux start --web

# Start Lux with web server on a specific port
lux start --web --port 8080

# Start Lux in daemon mode
lux daemon start
```

### Managing Projects

```bash
# Create a new Lux project
lux new my_project

# Generate a new agent
lux gen agent MyAgent

# Run tests
lux test
```

### Configuration

```bash
# Set configuration values
lux config set llm.provider openai

# View current configuration
lux config get
```

## Related Components

- [Lux Core](https://github.com/Spectral-Finance/lux/tree/main/core) - Core framework for building agent systems
- [Lux Web](https://github.com/Spectral-Finance/lux/tree/main/web) - Web interface for Lux

## License

Lux CLI is released under the MIT License. See [LICENSE](../LICENSE) for details. 