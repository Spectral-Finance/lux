# Contributing to Lux

Thank you for your interest in contributing to the Lux agent framework! This document provides everything you need to get started.

## Code of Conduct

This project adheres to a respectful and inclusive environment. Be kind, constructive, and collaborative in all interactions.

## Quick Start

```bash
# 1. Fork and clone
git clone https://github.com/YOUR_USERNAME/lux.git
cd lux

# 2. Set up development environment
# Install system dependencies:
#   - Elixir 1.18+, Erlang/OTP 27.2+
#   - Python 3.12+, Node.js 22.13+

# 3. Install project dependencies
cd lux
mix deps.get
mix compile

# 4. Run tests to verify setup
mix test.unit
mix python.test
```

## Project Structure

```
lux/
├── lux/                    # Core Lux framework
│   ├── lib/lux/            # Elixir source code
│   │   ├── agent.ex        # Agent definition and lifecycle
│   │   ├── agent_hub.ex    # Agent registry and discovery
│   │   ├── beam.ex         # Workflow orchestration
│   │   ├── prism.ex        # Pure function components
│   │   ├── lens.ex         # External data access
│   │   ├── signal.ex       # Inter-agent communication
│   │   ├── company.ex      # Organization orchestration
│   │   ├── memory.ex       # Memory backends
│   │   ├── llm.ex          # LLM integration layer
│   │   ├── python.ex       # Python bridge
│   │   └── nodejs.ex       # Node.js bridge
│   ├── test/               # ExUnit tests
│   │   ├── unit/           # Fast, isolated tests
│   │   ├── integration/    # Tests requiring external services
│   │   └── support/        # Test helpers
│   ├── guides/             # Documentation
│   ├── config/             # Compile-time configuration
│   ├── priv/python/        # Python code and dependencies
│   └── priv/node/          # Node.js code and dependencies
├── lux_app/                # Phoenix web application
├── scripts/                # Utility scripts
└── .github/workflows/      # CI/CD pipelines
```

## Development Workflow

### Branch Naming

Use descriptive branch names with a category prefix:

```
feat/telegram-integration      # New feature
fix/agent-memory-leak          # Bug fix
docs/api-reference-update      # Documentation
refactor/signal-dispatch       # Code restructuring
test/add-beam-coverage         # Test additions
```

### Commit Messages

Follow conventional commits:

```
feat(agent): add multi-provider LLM support
fix(signal): prevent duplicate dispatch on retry
docs(api): document AgentHub public functions
perf(beam): optimize AST traversal in Runner
test(prism): add schema validation edge cases
```

### Code Quality Gates

All PRs must pass:

```bash
mix format --check-formatted   # Code style (Elixir formatter)
mix credo                      # Static analysis and linting
mix dialyzer --format github   # Type checking
mix test.unit                  # Unit tests
mix python.test                # Python tests
mix coveralls.github           # Test coverage
```

Run these locally before pushing:

```bash
# Full local CI check
mix format && mix credo && mix test.unit && mix python.test
```

### Pull Request Process

1. **Create an issue** first for bugs and features (unless it's a minor doc fix)
2. **Fork and branch** from `main`
3. **Write tests** that cover your changes
4. **Update documentation** in `lux/guides/` if needed
5. **Run the full CI check** locally
6. **Submit PR** with:
   - Clear title using conventional commit format
   - Description of what changed and why
   - Link to related issue(s)
   - Screenshots or logs if relevant
   - Checklist confirming tests pass

## Adding Components

### Adding a New Prism

```elixir
# lux/lib/lux/prisms/my_feature_prism.ex
defmodule Lux.Prisms.MyFeaturePrism do
  use Lux.Prism,
    name: "My Feature",
    description: "Implements specific data transformation",
    input_schema: %{
      type: :object,
      properties: %{
        data: %{type: :array, description: "Input data array"},
        options: %{type: :object, description: "Transformation options"}
      },
      required: ["data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: :array},
        metadata: %{type: :object}
      }
    }

  @impl true
  def handler(%{data: data, options: opts}, _ctx) do
    transformed = process_data(data, opts)
    {:ok, %{result: transformed, metadata: %{count: length(transformed)}}}
  end

  defp process_data(data, opts) do
    # Implementation
    data
  end
end
```

### Adding a New Lens

```elixir
# lux/lib/lux/lenses/my_api_lens.ex
defmodule Lux.Lenses.MyAPILens do
  use Lux.Lens,
    name: "My External API",
    description: "Integrates with external service",
    url: "https://api.example.com/v1/:endpoint",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        endpoint: %{type: :string, description: "API endpoint path"},
        query: %{type: :string, description: "Search query"},
        limit: %{type: :integer, minimum: 1, maximum: 100}
      },
      required: ["endpoint"]
    },
    auth: %{type: :api_key, key: fn -> System.get_env("MY_API_KEY") end}

  def after_focus(%{"data" => data, "meta" => meta}) do
    {:ok, %{results: data, pagination: meta}}
  end

  def after_focus(%{"error" => error}) do
    {:error, "API error: #{error["message"]}"}
  end
end
```

### Adding a New Beam Workflow

```elixir
# lux/lib/lux/beams/my_workflow_beam.ex
defmodule Lux.Beams.MyWorkflowBeam do
  use Lux.Beam,
    name: "My Workflow",
    description: "Orchestrates multi-step data processing",
    input_schema: %{
      type: :object,
      properties: %{
        source: %{type: :string},
        transform: %{type: :string, enum: ["json", "csv"]}
      },
      required: ["source"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: :array},
        status: %{type: :string}
      }
    },
    generate_execution_log: true

  sequence do
    step(:fetch, Lux.Lenses.DataLens, %{
      source: :source
    }, store_io: true, retries: 3)

    parallel do
      step(:validate, Lux.Prisms.ValidatorPrism, %{
        data: {:ref, "fetch.results"}
      })

      step(:enrich, Lux.Prisms.EnricherPrism, %{
        data: {:ref, "fetch.results"}
      })
    end

    step(:transform, Lux.Prisms.TransformerPrism, %{
      validated: {:ref, "validate"},
      enriched: {:ref, "enrich"},
      format: :transform
    })

    step(:store, Lux.Prisms.StoragePrism, %{
      data: {:ref, "transform.result"},
      ttl: 3600
    })
  end
end
```

## Testing Guidelines

### Test Structure

```elixir
defmodule Lux.Prisms.MyPrismTest do
  use UnitCase, async: true

  describe "handler/2" do
    test "processes valid input correctly" do
      # Setup
      input = %{data: [1, 2, 3], options: %{multiplier: 2}}

      # Execute
      {:ok, result} = MyPrism.handler(input, %{})

      # Assert
      assert result.result == [2, 4, 6]
    end

    test "returns error for invalid input" do
      {:error, reason} = MyPrism.handler(%{data: nil, options: %{}}, %{})
      assert reason =~ "invalid"
    end

    test "handles edge case: empty array" do
      {:ok, result} = MyPrism.handler(%{data: [], options: %{}}, %{})
      assert result.result == []
      assert result.metadata.count == 0
    end
  end
end
```

### Test Coverage Expectations

- **New prisms**: 95%+ coverage, including error paths
- **New lenses**: 85%+ coverage, with Bypass for HTTP mocking
- **New beams**: All branches and fallback paths tested
- **Bug fixes**: Regression test that fails before the fix

## Documentation Guidelines

- **API docs**: Use `@moduledoc` and `@doc` with examples
- **Guides**: Add to `lux/guides/` for cross-cutting topics
- **Type specs**: Add `@spec` and `@type` for all public functions
- **Code examples**: Use working examples that can be verified in tests
- **Markdown**: Follow the existing style in `lux/guides/`

## Python Contribution Guidelines

### Adding Python Modules

```python
# priv/python/my_module.py
"""My Lux Python module.

Provides data processing utilities for Lux agents.
"""

from typing import Any, Dict, Optional


def view() -> Dict[str, Any]:
    """Return prism metadata."""
    return {
        "name": "Python Data Processor",
        "description": "Process data using Python libraries",
        "input_schema": {
            "type": "object",
            "properties": {
                "data": {"type": "array", "description": "Input data"},
            },
            "required": ["data"],
        },
    }


def handler(input_data: Dict[str, Any], context: Optional[Dict] = None) -> Dict[str, Any]:
    """Process input data."""
    data = input_data.get("data", [])
    processed = [item * 2 for item in data if isinstance(item, (int, float))]
    return {"ok": True, "result": processed, "count": len(processed)}
```

### Adding Python Dependencies

```bash
# Add to priv/python/pyproject.toml:
cd priv/python
poetry add pandas numpy

# Install for development:
poetry install
```

Requirements:
- Pin exact versions with hashes in `poetry.lock`
- Use `pip-audit` or `safety` for vulnerability scanning
- Add type hints to all public functions
- Follow PEP 8 with Black formatting

## Review Process

All contributions are reviewed against these criteria:

1. **Correctness**: Does it work as described?
2. **Tests**: Are edge cases and error paths covered?
3. **Documentation**: Are public APIs documented with examples?
4. **Style**: Does it follow Elixir/Python conventions?
5. **Performance**: Any obvious performance issues?
6. **Security**: No hardcoded secrets, input validation present?

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/Spectral-Finance/lux/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Spectral-Finance/lux/discussions)
- **Documentation**: Browse `lux/guides/` for detailed guides
- **Code Reference**: See `lux/lib/lux/` for module-level documentation

---

We appreciate every contribution — from a typo fix to a new integration. Thank you for helping make Lux better!
