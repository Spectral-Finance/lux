# Lux

<!-- [![Build Status](https://github.com/spectrallabs/lux/workflows/CI/badge.svg)](https://github.com/spectrallabs/lux/actions) -->
<!-- [![Hex.pm](https://img.shields.io/hexpm/v/lux.svg)](https://hex.pm/packages/lux)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/lux) -->

> ⚠️ **Note**: Lux is currently under heavy development and should be considered pre-alpha software. The API and architecture are subject to significant changes. We welcome feedback and contributions.

Lux is a powerful Elixir framework for building intelligent, adaptive, and collaborative multi-agent systems. It enables autonomous entities (Agents) to communicate, learn, and execute complex workflows while continuously improving through reflection.

## Why Lux?

- 🧠 **Self-Improving Agents**: Agents with built-in reflection capabilities (coming soon)
- 🚀 **Modular Architecture**: Build complex systems from simple, reusable components
- 🔄 **Type-Safe Communication**: Structured data flow with schema validation
- 🤖 **AI-First**: Deep LLM integration with advanced prompting and context management
- 🔌 **Extensible**: Easy integration with external services and APIs
- 📊 **Observable**: Built-in monitoring, metrics, and debugging tools
- 🧪 **Testable**: Comprehensive testing utilities for deterministic agent behavior

## Quick Start

```elixir
# Add Lux to your dependencies
def deps do
  [
    {:lux, "~> 0.1.0"}
  ]
end

# First, define a signal schema
defmodule MyApp.Schemas.MarketSignal do
  use Lux.SignalSchema,
    id: "market-signal",
    name: "Market Signal",
    description: "Market data and trading signals",
    schema: %{
      type: :object,
      properties: %{
        asset: %{type: :string},
        action: %{type: :string, enum: ["buy", "sell", "hold"]},
        price: %{type: :number},
        confidence: %{type: :number}
      },
      required: ["asset", "action", "price"]
    }
end

# Create an intelligent agent (Agent)
defmodule MyApp.Agents.TradingAgent do
  use Lux.Agent

  def new do
    Lux.Agent.new(%{
      name: "Trading Agent",
      description: "Analyzes market data and executes trades",
      goal: "Maximize portfolio returns while managing risk",
      prisms: [
        MyApp.Prisms.MarketAnalysis,
        MyApp.Prisms.RiskAssessment,
        MyApp.Prisms.OrderExecution
      ]
    })
  end

  # Handle incoming market signals
  def handle_signal(agent, %{schema_id: MyApp.Schemas.MarketSignal} = signal) do
    case signal.payload.action do
      "buy" -> 
        {:ok, [{MyApp.Prisms.OrderExecution, Map.put(signal.payload, :type, :market_buy)}]}
      "sell" -> 
        {:ok, [{MyApp.Prisms.OrderExecution, Map.put(signal.payload, :type, :market_sell)}]}
      "hold" ->
        :ignore
    end
  end

  # Ignore other signal types
  def handle_signal(_agent, _signal), do: :ignore
end

# Start and interact with your agent
{:ok, pid} = MyApp.Agents.TradingAgent.start_link()
```

## Core Concepts

Lux is built around four powerful abstractions:

### 1. Agents 👻
Autonomous agents that combine intelligence and execution:
```elixir
defmodule MyApp.Agents.CryptoHedgeFundCEO do
  use Lux.Agent

  def new do
    Lux.Agent.new(%{
      name: "Crypto Hedge Fund CEO",
      description: "Strategic decision maker for crypto investments",
      goal: "Maximize fund performance and manage risk",
      prisms: [
        MyApp.Prisms.PortfolioAnalysis,
        MyApp.Prisms.MarketResearch,
        MyApp.Prisms.RiskManagement
      ],
      # Enable collaboration with other agents
      collaboration_config: %{
        trusted_agents: [
          "trading-desk-head",
          "risk-manager",
          "research-analyst"
        ],
        collaboration_protocols: [:ask, :tell, :delegate]
      }
    })
  end
  
  # Handle performance reports
  def handle_signal(agent, %{schema_id: MyApp.Schemas.PerformanceReport} = signal) do
    case analyze_performance(signal.payload) do
      {:rebalance, changes} ->
        {:ok, [
          {MyApp.Prisms.PortfolioRebalance, changes},
          {MyApp.Prisms.NotifyStakeholders, %{type: :portfolio_update}}
        ]}
      {:investigate, metrics} ->
        {:ok, [
          {MyApp.Prisms.RiskAnalysis, metrics},
          {MyApp.Prisms.RequestAnalystReport, metrics}
        ]}
      :satisfactory ->
        :ignore
    end
  end

  # Handle market alerts
  def handle_signal(agent, %{schema_id: MyApp.Schemas.MarketAlert} = signal) do
    {:ok, [
      {MyApp.Prisms.EmergencyAssessment, signal.payload},
      {MyApp.Prisms.NotifyRiskManager, signal.payload}
    ]}
  end

  # Ignore other signals
  def handle_signal(_agent, _signal), do: :ignore
end

# Start the CEO agent
{:ok, ceo_pid} = MyApp.Agents.CryptoHedgeFundCEO.start_link()

# The CEO agent will:
# - Monitor fund performance
# - Delegate trading decisions
# - Manage risk exposure
# - Coordinate with other agents
# - Adapt strategy based on market conditions
```

### 2. Signals 📡
Type-safe communication using predefined schemas:
```elixir
# Define a schema for performance reports
defmodule MyApp.Schemas.PerformanceReport do
  use Lux.SignalSchema,
    id: "performance-report",
    name: "Fund Performance Report",
    description: "Daily fund performance metrics",
    schema: %{
      type: :object,
      required: [:date, :returns, :risk_metrics],
      properties: %{
        date: %{type: :string, format: :date},
        returns: %{
          type: :object,
          properties: %{
            daily: %{type: :number},
            mtd: %{type: :number},
            ytd: %{type: :number}
          }
        },
        risk_metrics: %{
          type: :object,
          properties: %{
            sharpe_ratio: %{type: :number},
            volatility: %{type: :number},
            max_drawdown: %{type: :number}
          }
        }
      }
    }
end

# Create a signal using the schema
signal = Lux.Signal.new(%{
  schema_id: MyApp.Schemas.PerformanceReport,
  payload: %{
    date: "2024-03-14",
    returns: %{daily: 0.025, mtd: 0.15, ytd: 0.45},
    risk_metrics: %{
      sharpe_ratio: 2.1,
      volatility: 0.18,
      max_drawdown: 0.12
    }
  }
})
```

### 3. Prisms 🔮
Pure functional components for specific tasks:
```elixir
defmodule MyApp.Prisms.RiskAssessment do
  use Lux.Prism,
    name: "Risk Assessment",
    description: "Evaluates portfolio risk metrics",
    input_schema: MyApp.Schemas.PortfolioState,
    output_schema: MyApp.Schemas.RiskMetrics

  def handler(%{portfolio: portfolio}, _ctx) do
    {:ok, %{
      risk_score: calculate_risk_score(portfolio),
      exposure_metrics: calculate_exposures(portfolio),
      recommendations: generate_risk_recommendations(portfolio)
    }}
  end
end
```
[Learn more about Prisms](guides/prisms.md)

### 4. Beams 🌟
Composable workflow orchestrators:
```elixir
defmodule MyApp.Beams.PortfolioRebalancing do
  use Lux.Beam,
    name: "Portfolio Rebalancing",
    description: "End-to-end portfolio rebalancing workflow"

  def steps do
    sequence do
      step(:analyze, MyApp.Prisms.PortfolioAnalysis, %{
        compute_metrics: true,
        include_history: true
      })

      parallel do
        step(:risk, MyApp.Prisms.RiskAssessment, %{
          portfolio: {:ref, "analyze.portfolio"},
          metrics: {:ref, "analyze.metrics"}
        })

        step(:market, MyApp.Prisms.MarketAnalysis, %{
          assets: {:ref, "analyze.assets"}
        })
      end

      step(:optimize, MyApp.Prisms.PortfolioOptimization, %{
        current_state: {:ref, "analyze"},
        risk_assessment: {:ref, "risk"},
        market_data: {:ref, "market"}
      })

      step(:execute, MyApp.Prisms.TradeExecution, %{
        trades: {:ref, "optimize.trades"}
      })
    end
  end
end
```
[Learn more about Beams](guides/beams.md)

## Python Integration

Lux provides seamless Python integration using heredocs, making it easy to leverage Python's rich ecosystem directly in your Elixir code. Here's an example using eth_abi to decode smart contract events:

```elixir
defmodule MyApp.Lenses.EtherscanLens do
  use Lux.Lens,
    name: "Etherscan Lens",
    description: "Fetches and decodes contract events",
    url: "https://api.etherscan.io/api",
    auth: %{
      type: :api_key,
      key: System.get_env("ETHERSCAN_API_KEY")
    }

  require Lux.Python
  import Lux.Python

  def after_focus(response) do
    # Import required Python packages
    {:ok, %{success: true}} = Lux.Python.import_package("eth_abi")
    {:ok, %{success: true}} = Lux.Python.import_package("eth_utils")

    # Execute Python code with variable bindings
    result = python variables: %{logs: response["result"]} do
      ~PY"""
      from eth_abi import decode
      from eth_utils import event_abi_to_log_topic

      # ERC20 Transfer event topic
      transfer_topic = event_abi_to_log_topic({
          'type': 'event',
          'name': 'Transfer',
          'inputs': [
              {'type': 'address', 'indexed': True},
              {'type': 'address', 'indexed': True},
              {'type': 'uint256', 'indexed': False}
          ]
      })

      # Decode transfer events
      transfers = [{
          'from': decode(['address'], bytes.fromhex(log['topics'][1][2:]))[0].hex(),
          'to': decode(['address'], bytes.fromhex(log['topics'][2][2:]))[0].hex(),
          'value': decode(['uint256'], bytes.fromhex(log['data'][2:]))[0]
      } for log in logs if log['topics'][0] == transfer_topic]

      {'transfers': transfers}
      """
    end

    {:ok, result}
  end
end

# Use the lens
{:ok, result} = MyApp.Lenses.EtherscanLens.focus(%{
  module: "account",
  action: "txlist",
  address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
  startblock: "0",
  endblock: "99999999"
}, with_after_focus: true)
```

This example shows how to:
- Define a lens with proper URL and authentication
- Transform API responses using Python in `after_focus`
- Use powerful Python libraries for blockchain data processing
- Handle complex binary data efficiently

The Python code is executed in an isolated environment and has access to all installed Python packages. You can use this approach to leverage any Python library, from machine learning frameworks to data processing tools.


## Development Setup

### Prerequisites
- [asdf](https://asdf-vm.com/) version manager
- That's it! Everything else will be installed automatically

### Quick Setup
```bash
# Clone the repository
git clone https://github.com/spectrallabs/lux.git
cd lux

# Install Elixir, Erlang, Python and Node.js with the correct versions
asdf install

# Install all dependencies (Elixir and Python)
mix setup

# Optionally, run tests
mix test.suite
```

### Setup Python environment

```sh
cd priv/python
poetry shell
poetry install
```

### Setup environment variables

The application uses environment-specific configuration files:
- `dev.envrc` for development
- `test.envrc` for testing
- `prod.envrc` for production

1. Create the appropriate `.envrc` file for your environment.

```sh
# For development
cp dev.envrc dev.override.envrc

# For testing
cp test.envrc test.override.envrc
```

These files are optional and can be used for local-specific configurations that shouldn't be committed to version control.
- `dev.override.envrc`
- `test.override.envrc`
- `prod.override.envrc`

3. Fill in required API keys in your environment file

## Contributing

We welcome contributions! Here's how you can help:

1. 🐛 Report bugs and suggest features in [Issues](https://github.com/spectrallabs/lux/issues)
2. 📖 Improve documentation
3. 🧪 Add tests and examples
4. 🔧 Submit pull requests

See our [Contributing Guide](CONTRIBUTING.md) for details.

## Community

- 💬 [Discord Community](https://discord.gg/luxframework)
- 📝 [Blog](https://blog.spectrallabs.xyz)
- 🐦 [Twitter](https://twitter.com/luxframework)

## License

Lux is released under the MIT License. See [LICENSE](LICENSE) for details.
