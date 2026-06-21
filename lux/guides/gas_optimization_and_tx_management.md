# Gas Optimization and Transaction Management

The Lux framework provides powerful prisms to handle gas optimization and transaction management out-of-the-box, specifically designed to help agentic systems interact safely and cost-effectively with Ethereum and EVM-compatible chains.

## Prisms

### GasOptimizerPrism

The `Lux.Prisms.GasOptimizerPrism` handles predicting gas prices, optimizing priority fees, and performing cost analysis.

```elixir
alias Lux.Prisms.GasOptimizerPrism

# Predict gas prices
{:ok, prediction} = GasOptimizerPrism.run(%{
  action: "predict",
  network: "mainnet"
})

# Optimize priority fees
{:ok, fees} = GasOptimizerPrism.run(%{
  action: "priority_fee",
  network: "mainnet"
})

# Cost analysis for a transaction
{:ok, analysis} = GasOptimizerPrism.run(%{
  action: "cost_analysis",
  network: "mainnet",
  gas_limit: 21000
})
```

### TxManagerPrism

The `Lux.Prisms.TxManagerPrism` handles transaction simulation, batching, replacement, MEV protection, and gas token integration.

```elixir
alias Lux.Prisms.TxManagerPrism

# Simulate a transaction
{:ok, sim} = TxManagerPrism.run(%{
  action: "simulate",
  network: "mainnet",
  payload: %{
    "transaction" => %{
      "to" => "0xTargetAddress",
      "value" => 1000000000000000000
    }
  }
})

# Replace a transaction (Speed up)
{:ok, replacement} = TxManagerPrism.run(%{
  action: "replace",
  network: "mainnet",
  payload: %{
    "tx_hash" => "0xOldTxHash",
    "type" => "speed_up"
  }
})

# Send with MEV Protection
{:ok, mev} = TxManagerPrism.run(%{
  action: "mev_protect",
  network: "mainnet",
  payload: %{
    "transaction" => %{
      "to" => "0xTargetAddress",
      "data" => "0xData"
    }
  }
})
```

These utilities allow agents to be robust against network congestion and reduce costs effectively.
