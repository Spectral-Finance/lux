# Lux Core

[![Hex.pm](https://img.shields.io/hexpm/v/lux_core.svg)](https://hex.pm/packages/lux_core)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lux_core)

> ⚠️ **Note**: Lux is currently under heavy development and should be considered pre-alpha software. The API and architecture are subject to significant changes. We welcome feedback and contributions.

Lux Core is the foundation of the Lux framework, providing the essential components for building intelligent, adaptive, and collaborative multi-agent systems. It enables autonomous entities (Agents) to communicate, learn, and execute complex workflows while continuously improving through reflection.

## Core Components

### 1. Agents 👻

Autonomous agents that combine intelligence and execution. Agents can:
- Monitor and analyze data
- Make strategic decisions
- Delegate tasks to other agents
- Adapt to changing conditions
- Collaborate through structured protocols

### 2. Signals 📡

Type-safe communication using predefined schemas. Signals provide:
- Structured data validation
- Type safety across language boundaries
- Clear communication protocols
- Versioning and compatibility

### 3. Prisms 🔮

Pure functional components for specific tasks. Prisms enable:
- Modular functionality
- Language-specific implementations
- Clear input/output contracts
- Easy testing and validation

### 4. Beams 🌟

Composable workflow orchestrators. Beams allow you to:
- Define complex workflows
- Coordinate multiple agents
- Handle parallel execution
- Manage state and dependencies

## Installation

Add `lux_core` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:lux_core, "~> 0.5.0"}
  ]
end
```

## Usage

```elixir
defmodule MyApp.SimpleAgent do
  use Lux.Agent,
    name: "Simple Agent",
    description: "A simple agent that responds to greetings",
    goal: "To be friendly and helpful"

  def init(opts) do
    {:ok, opts}
  end

  def handle_signal(%{type: "greeting", data: %{"message" => message}}, state) do
    response = "Hello! You said: #{message}"
    {:reply, %{type: "response", data: %{"message" => response}}, state}
  end
end
```

## Related Components

- [Lux Web](https://github.com/Spectral-Finance/lux/tree/main/web) - Web interface for Lux
- [Lux CLI](https://github.com/Spectral-Finance/lux/tree/main/cli) - Command-line interface for Lux

## License

Lux Core is released under the MIT License. See [LICENSE](../LICENSE) for details. 