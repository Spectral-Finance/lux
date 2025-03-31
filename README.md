# Lux

<!-- [![Build Status](https://github.com/spectrallabs/lux/workflows/CI/badge.svg)](https://github.com/spectrallabs/lux/actions) -->
[![Lux CI](https://github.com/Spectral-Finance/lux/actions/workflows/lux-ci.yml/badge.svg)](https://github.com/Spectral-Finance/lux/actions/workflows/lux-ci.yml)
[![Lux App CI](https://github.com/Spectral-Finance/lux/actions/workflows/lux-app-ci.yml/badge.svg)](https://github.com/Spectral-Finance/lux/actions/workflows/lux-app-ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/lux.svg)](https://hex.pm/packages/lux)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lux)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

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
- [Getting Started Guide](lux/guides/getting_started.md) - Start here if you're new to Lux
- [Core Concepts](lux/guides/core_concepts.md) - Learn about Agents, Signals, Prisms, and Beams
- [Language Support](lux/guides/language_support.md) - Language integration details

### Core Concepts
- [Agents](lux/guides/agents.livemd) - Building intelligent autonomous agents
- [Signals](lux/guides/signals.livemd) - Type-safe communication between agents
- [Prisms](lux/guides/prisms.livemd) - Modular functional components
- [Beams](lux/guides/beams.livemd) - Workflow orchestration
- [Lenses](lux/guides/lenses.livemd) - External service integration

### Examples & Guides
- [Multi-Agent Collaboration](lux/guides/multi_agent_collaboration.livemd) - Build collaborative systems
- [Trading System](lux/guides/trading_system.livemd) - Complete crypto trading example
- [Running a Company](lux/guides/running_a_company.livemd) - Multi-agent content creation pipeline
- [Role Management](lux/guides/role_management.md) - Managing agent roles
- [Companies](lux/guides/companies.md) - Organizing agents into companies

### Development
- [Contributing Guide](lux/guides/contributing.md) - Help improve Lux
- [Testing Guide](lux/guides/testing.md) - Testing your Lux applications
- [Troubleshooting](lux/guides/troubleshooting.md) - Common issues and solutions

## Core Concepts

### 1. Agents 👻
[Learn more about Agents](lux/guides/agents.livemd)

Autonomous agents that combine intelligence and execution. Agents can:
- Monitor and analyze data
- Make strategic decisions
- Delegate tasks to other agents
- Adapt to changing conditions
- Collaborate through structured protocols

### 2. Signals 📡
[Learn more about Signals](lux/guides/signals.livemd)

Type-safe communication using predefined schemas. Signals provide:
- Structured data validation
- Type safety across language boundaries
- Clear communication protocols
- Versioning and compatibility

### 3. Prisms 🔮
[Learn more about Prisms](lux/guides/prisms.livemd)

Pure functional components for specific tasks. Prisms enable:
- Modular functionality
- Language-specific implementations
- Clear input/output contracts
- Easy testing and validation

### 4. Beams 🌟
[Learn more about Beams](lux/guides/beams.livemd)

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

[Learn more about language support](lux/guides/language_support.md)

## Examples

Check out these examples to see Lux in action:

- [Trading System](lux/guides/trading_system.livemd): A complete crypto trading system
- [Content Creation](lux/guides/running_a_company.livemd): Multi-agent content creation pipeline
- [Research Assistant](lux/guides/multi_agent_collaboration.livemd): Collaborative research system

## Contributing

We welcome contributions! Whether you want to add support for a new language, improve documentation, or fix bugs, check out our [Contributing Guide](lux/guides/contributing.md).

## Community

- 💬 [Discord Community](https://discord.gg/dsRPcjeH)
- 📝 [Blog](https://blog.spectrallabs.xyz)
- 🐦 [Twitter](https://twitter.com/Spectral_Labs)

## License

Lux is released under the MIT License. See [LICENSE](LICENSE) for details.

### Using GitHub Codespaces

Lux supports development using GitHub Codespaces, providing a pre-configured development environment with all necessary dependencies. To get started:

1. Click the "Code" button on the GitHub repository
2. Select "Create codespace on main"
3. Wait for the environment to be created (this may take a few minutes)

The Codespace comes with:
- Elixir/Erlang environment (matching .tool-versions)
- Python environment with virtual env
- Node.js environment
- VS Code extensions for Elixir, Python, and JavaScript development
- GitHub CLI
- Phoenix Framework
- Livebook integration
- All necessary development tools

The environment will automatically:
- Install all Elixir dependencies for both Lux and LuxApp
- Set up a Python virtual environment
- Install required Python packages
- Configure VS Code settings for optimal development
- Install and configure Livebook

To set up the development environment:
1. Open VS Code's Command Palette (Cmd/Ctrl + Shift + P)
2. Type "Tasks: Run Build Task" and select it (or use Cmd/Ctrl + Shift + B)
3. This will run the "Initialize Environment" task which:
   - Installs Elixir dependencies for both Lux and LuxApp
   - Sets up Python virtual environment and dependencies
   - Installs Node.js dependencies
   - Installs and configures Livebook

To start the development servers:
1. Open VS Code's Command Palette (Cmd/Ctrl + Shift + P)
2. Type "Tasks: Run Task" and select it
3. Choose "Start All Services" to launch both LuxApp and Livebook
4. Access:
   - LuxApp at port 4000
   - Livebook at port 4001 (no authentication required in dev mode)
   - Additional ports 8080 and 8081 are available for your services

Available Tasks:
Setup Tasks:
- "Initialize Environment" - Sets up all dependencies (default build task)
- "Install Elixir Dependencies" - Installs Lux dependencies
- "Install LuxApp Dependencies" - Installs LuxApp dependencies
- "Install Python Dependencies" - Sets up Python environment
- "Install Node.js Dependencies" - Installs Node.js packages
- "Install Livebook" - Installs Livebook

Service Tasks:
- "Start All Services" - Launches both servers (default test task)
- "Start LuxApp Server" - Starts only the Phoenix server
- "Start Livebook" - Starts only the Livebook server

For development:
- The main Lux library is in the root directory
- LuxApp is in the `lux_app` directory
- Livebook notebooks can be created and run directly in the browser
- All necessary ports are automatically forwarded
- VS Code is configured for Elixir, Phoenix, and LiveView development
