# Getting Started with Lux

Lux is a powerful language-agnostic framework for building intelligent, adaptive, and collaborative multi-agent systems. This guide will help you get started with Lux development.

## Prerequisites

Before installing Lux, ensure you have:

- [asdf](https://asdf-vm.com/) version manager installed
- Git
- A Unix-like operating system (macOS or Linux)
- Basic knowledge of Elixir, Python, and Node.js

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/Spectral-Finance/lux.git
cd lux/lux
```

### 2. System Dependencies

#### For macOS:

```bash
make setup-mac
```

This will install required dependencies using Homebrew:
- autoconf
- automake
- libtool
- wxmac
- fop
- openssl@3

#### For Linux (Debian/Ubuntu):

```bash
make setup-linux
```

This will install required system packages including:
- build-essential
- autoconf
- libncurses5-dev
- libwxgtk3.0-gtk3-dev
- And other necessary dependencies

### 3. Project Setup

Run the complete setup:

```bash
make setup
```

This will:
1. Configure your shell for asdf
2. Install required asdf plugins and tools
3. Set up project dependencies including:
   - Elixir dependencies via mix
   - Python dependencies via Poetry
   - Node.js dependencies via npm

### 4. Verify Installation

Run the test suite to verify your installation:

```bash
make test
```

## Project Structure

A typical Lux project consists of:

```
lux/
├── lib/              # Elixir source code
├── priv/
│   ├── python/      # Python modules and dependencies
│   └── node/        # Node.js modules and dependencies
├── test/            # Test files
└── guides/          # Documentation and guides
```

## Core Concepts

Lux is built around several key components:

1. **Agents**: Autonomous components that can interact with LLMs, process signals, and execute workflows
2. **Signals**: Type-safe communication between components
3. **Prisms**: Modular units of functionality that can be composed into workflows
4. **Beams**: Orchestration layer for composing components into complex workflows
5. **Lenses**: Integration points with external systems and APIs

For detailed information about each component, refer to their respective guides:
- [Agents Guide](agents.livemd)
- [Signals Guide](signals.livemd)
- [Prisms Guide](prisms.livemd)
- [Beams Guide](beams.livemd)
- [Lenses Guide](lenses.livemd)

## Language Support

Lux supports multiple programming languages:

- **Elixir**: Core framework and coordination
- **Python**: ML/AI tasks and data processing
- **Node.js**: Web integration and text processing

Each language has its own guide:
- [Python Guide](language_support/python.livemd)
- [Node.js Guide](language_support/nodejs.livemd)
- Additional language support coming soon!

## Development Tools

### Using Docker (Coming Soon)

A Docker-based development environment is under development and will be available soon.

### IDE Support

For the best development experience, we recommend using [Cursor](https://cursor.sh) with the provided development configurations. See the [Cursor Development Guide](cursor_development.md) for setup instructions.

## Next Steps

1. Review the [Multi-Agent Collaboration Guide](multi_agent_collaboration.livemd) for examples of building agent systems
2. Check out the [Trading System Example](trading_system.livemd) for a complete application
3. Learn about organizing agents in [Companies Guide](companies.md)
4. Explore [Running a Company](running_a_company.livemd) for complex workflows

## Testing and Troubleshooting

- Read our [Testing Guide](testing.md) for best practices
- Check the [Troubleshooting Guide](troubleshooting.md) for common issues and solutions

## Contributing

We welcome contributions! Check out our [Contributing Guide](contributing.md) to get started.

## License

Lux is released under the MIT License. See [LICENSE](../LICENSE) for details. 
