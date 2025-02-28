# Lux

<!-- [![Build Status](https://github.com/spectrallabs/lux/workflows/CI/badge.svg)](https://github.com/spectrallabs/lux/actions) -->
[![Lux CI](https://github.com/Spectral-Finance/lux/actions/workflows/lux-ci.yml/badge.svg)](https://github.com/Spectral-Finance/lux/actions/workflows/lux-ci.yml)
[![Lux App CI](https://github.com/Spectral-Finance/lux/actions/workflows/lux-app-ci.yml/badge.svg)](https://github.com/Spectral-Finance/lux/actions/workflows/lux-app-ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/lux.svg)](https://hex.pm/packages/lux)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lux)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> ⚠️ **Note**: Lux is currently under heavy development and should be considered pre-alpha software. The API and architecture are subject to significant changes. We welcome feedback and contributions.

Lux is a powerful language-agnostic framework for building intelligent, adaptive, and collaborative multi-agent systems. It enables autonomous entities (Agents) to communicate, learn, and execute complex workflows while continuously improving through reflection.

## Why Lux?

- 🧠 **Self-Improving Agents**: Agents with built-in reflection capabilities (coming soon)
- 🚀 **Language Agnostic**: Build agents in your favorite programming language
- 🔄 **Type-Safe Communication**: Structured data flow with schema validation
- 🤖 **AI-First**: Deep LLM integration with advanced prompting and context management
- 🔌 **Extensible**: Easy integration with external services and APIs
- 📊 **Observable**: Built-in monitoring, metrics, and debugging tools
- 🧪 **Testable**: Comprehensive testing utilities for deterministic agent behavior

## Documentation

📚 [Read the full documentation on hexdocs.pm/lux](https://hexdocs.pm/lux)

### Getting Started
- [Getting Started Guide](guides/getting_started.md) (docs coming soon) - Start here if you're new to Lux
- [Core Concepts](guides/core_concepts.md) (docs coming soon) - Learn about Agents, Signals, Prisms, and Beams
- [Language Support](guides/language_support.md) (docs coming soon) - Language integration details

## Docker Setup

### Prerequisites
- Docker installed on your system
- Docker Compose (optional, for easier management)

### Using Docker

Lux provides a Docker setup for easy development and testing. This eliminates the need to manually install dependencies on your local machine.

#### Building the Docker Image

```bash
# Navigate to the Lux repository
cd lux

# Build the Docker image
docker build -t lux-dev .
```

#### Running the Container

```bash
# Run the container interactively
docker run -it --name lux_dev lux-dev

# Or using Docker Compose
docker-compose up -d
docker exec -it lux_dev bash
```

#### Running Tests Inside the Container

Once inside the container, you can run tests:

```bash
cd /workspace/lux
make test
```

The Docker environment comes with all necessary dependencies pre-installed, including:
- Erlang and Elixir (via asdf)
- Python with required packages (web3, nltk, eth-tester, py-evm)
- Node.js
- All system dependencies for development

### Core Concepts
- [Agents](guides/agents.livemd) - Building intelligent autonomous agents
- [Signals](guides/signals.livemd) - Type-safe communication between agents
- [Prisms](guides/prisms.livemd) - Modular functional components
- [Beams](guides/beams.livemd) - Workflow orchestration
- [Lenses](guides/lenses.livemd) - External service integration

### Examples & Guides
- [Multi-Agent Collaboration](guides/multi_agent_collaboration.livemd) - Build collaborative systems
- [Trading System](guides/trading_system.livemd) - Complete crypto trading example
- [Running a Company](guides/running_a_company.livemd) - Multi-agent content creation pipeline
- [Role Management](guides/role_management.md) - Managing agent roles
- [Companies](guides/companies.md) - Organizing agents into companies

### Development
- [Contributing Guide](guides/contributing.md) - Help improve Lux
- [Testing Guide](guides/testing.md) - Testing your Lux applications
- [Troubleshooting](guides/troubleshooting.md) - Common issues and solutions

## Core Concepts

### 1. Agents 👻
[Learn more about Agents](guides/agents.livemd)

Autonomous agents that combine intelligence and execution. Agents can:
- Monitor and analyze data
- Make strategic decisions
- Delegate tasks to other agents
- Adapt to changing conditions
- Collaborate through structured protocols

### 2. Signals 📡
[Learn more about Signals](guides/signals.livemd)

Type-safe communication using predefined schemas. Signals provide:
- Structured data validation
- Type safety across language boundaries
- Clear communication protocols
- Versioning and compatibility

### 3. Prisms 🔮
[Learn more about Prisms](guides/prisms.livemd)

Pure functional components for specific tasks. Prisms enable:
- Modular functionality
- Language-specific implementations
- Clear input/output contracts
- Easy testing and validation

### 4. Beams 🌟
[Learn more about Beams](guides/beams.livemd)

Composable workflow orchestrators. Beams allow you to:
- Define complex workflows
- Coordinate multiple agents
- Handle parallel execution
- Manage state and dependencies

## Language Support

Lux provides first-class support for multiple programming languages:

- **Python**: Deep integration with Python's scientific and ML ecosystem
- **JavaScript/TypeScript**: Frontend and Node.js support
- **Other Languages**: Language-agnostic protocols for easy integration

[Learn more about language support](guides/language_support.md)

## Examples

Check out these examples to see Lux in action:

- [Trading System](guides/trading_system.livemd): A complete crypto trading system
- [Content Creation](guides/running_a_company.livemd): Multi-agent content creation pipeline
- [Research Assistant](guides/multi_agent_collaboration.livemd): Collaborative research system

## Contributing

We welcome contributions! Whether you want to add support for a new language, improve documentation, or fix bugs, check out our [Contributing Guide](guides/contributing.md).

## Community

- 💬 [Discord Community](https://discord.gg/luxframework)
- 📝 [Blog](https://blog.spectrallabs.xyz)
- 🐦 [Twitter](https://twitter.com/luxframework)

## License

Lux is released under the MIT License. See [LICENSE](LICENSE) for details.
