# Gas Optimization and Transaction Management in Lux

This guide covers the architecture, configuration, and practical usage of the Gas Optimization and Transaction Management subsystem in Lux (`Lux.Web3.Gas`).

---

## 1. Overview

Executing transactions on Ethereum and EVM-compatible networks requires balance between cost efficiency, confirmation latency, and MEV protection. The Lux Gas Management subsystem provides enterprise-grade tools for AI agents and autonomous workflows:

- **EIP-1559 Gas Price Prediction:** Deterministic next-block base fee calculations, moving average tracking, network congestion categorization, and priority fee recommendations.
- **Transaction Batching:** Multicall3 aggregation bundling multiple operations into a single atomic transaction, saving upwards of 25-40% in base gas overhead.
- **Transaction Replacement (RBF):** Compliant Replace-By-Fee speed-up and cancellation mechanism honoring the mandatory 10% fee escalation rule.
- **MEV & Frontrunning Protection:** Automated slippage risk scoring, sandwich vulnerability detection, and private mempool routing via Flashbots Protect and MEV-Blocker.
- **Simulation & Revert Decoding:** Pre-flight dry-run execution, safety margin buffering, EVM Panic/Error decoding, and EIP-2930 Access List optimization.
- **Cost Analysis & Reporting:** Granular cost breakdown across Wei, Gwei, ETH, and USD with ROI and gas savings metrics.
- **First-Class Prism:** `Lux.Prisms.GasOptimizerPrism` enables autonomous agents to optimize and dispatch transactions effortlessly.

---

## 2. Architecture & Modules

The system is organized modularly under `lib/lux/web3/gas/` with a unified coordinator at `lib/lux/web3/gas.ex`:

```
lib/lux/
├── web3/
│   ├── gas.ex                          # Coordinator & public facade
│   └── gas/
│       ├── predictor.ex                # EIP-1559 fee prediction & congestion scoring
│       ├── batcher.ex                  # Multicall3 batch bundling & gas savings
│       ├── replacement_manager.ex      # Speed-up & cancellation (RBF)
│       ├── mev_guard.ex                # Sandwich risk & private RPC routing
│       ├── simulator.ex                # Simulation, revert decoding & EIP-2930 access list
│       └── reporter.ex                 # Multi-currency cost reports & savings tables
└── prisms/
    └── gas_optimizer_prism.ex          # Agent-ready Prism for workflow orchestration
```

---

## 3. Core Features & Usage

### 3.1 Gas Price Prediction (`Lux.Web3.Gas.Predictor`)

Calculates exact next-block base fees according to EIP-1559 consensus rules:

$$\Delta = \text{base\_fee} \times \frac{|\text{gas\_used} - \text{target\_gas}|}{\text{target\_gas} \times 8}$$

```elixir
alias Lux.Web3.Gas

# Predict fees for a given urgency tier (:slow, :standard, :fast, :instant)
recommendation = Gas.predict_fees(:fast, %{
  history: [
    %{gas_used: 28_000_000, gas_limit: 30_000_000, base_fee: 25_000_000_000, tips: [2.0, 3.5]}
  ]
})

# recommendation.base_fee_gwei => 27.7
# recommendation.max_priority_fee_gwei => 4.2
# recommendation.max_fee_gwei => 38.8
# recommendation.congestion_level => :extreme
```

### 3.2 Transaction Batching (`Lux.Web3.Gas.Batcher`)

Combines multiple smart contract interactions into a single Multicall3 call, avoiding redundant 21,000 gas transaction overhead:

```elixir
calls = [
  %{target: "0xdac17f958d2ee523a2206206994597c13d831ec7", call_data: "0xa9059cbb...", allow_failure: false},
  %{target: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", call_data: "0xa9059cbb...", allow_failure: true}
]

{:ok, batch} = Gas.create_batch(calls)
# batch.gas_saved => ~21,000 gas saved
# batch.savings_percentage => ~22.5%
# batch.multicall_address => "0xcA11bde05977b3631167028862bE2a173976CA11"
```

### 3.3 Replace-By-Fee (RBF) Management (`Lux.Web3.Gas.ReplacementManager`)

Quickly unsticks transactions in mempool congestion or cancels stale orders:

```elixir
stuck_tx = %{
  nonce: 104,
  from: "0x123...",
  to: "0x456...",
  max_fee_per_gas: 30_000_000_000,
  max_priority_fee_per_gas: 1_500_000_000
}

# Speed up with a 20% gas price bump
{:ok, speed_up_tx} = Gas.speed_up(stuck_tx, 1.20)

# Cancel with an immediate 0-value self-transaction
{:ok, cancel_tx} = Gas.cancel(stuck_tx, 1.25)
```

### 3.4 MEV Protection (`Lux.Web3.Gas.MevGuard`)

Protects decentralized trades and liquidations against sandwich attacks:

```elixir
trade_params = %{
  action_type: :swap,
  slippage_percentage: 2.5,
  value_eth: 8.5
}

mev = Gas.protect_mev(trade_params)
# mev.risk_level => :critical
# mev.recommended_route => :flashbots
# mev.requires_private_relay => true
```

### 3.5 Transaction Simulation & Revert Decoding (`Lux.Web3.Gas.Simulator`)

Decodes standard revert reasons (`Error(string)`), Solidity Panic codes (e.g. arithmetic overflow, out of bounds), and calculates EIP-2930 storage access savings:

```elixir
sim = Gas.simulate(%{
  estimated_gas: 120_000,
  access_list: [%{storage_keys: ["0x01", "0x02"]}],
  gas_token_burn: 1
}, safety_margin: 1.20)

# sim.recommended_gas_limit => 144_000
# sim.access_list_savings => 400
# sim.gas_refund => 24_000
```

### 3.6 Cost Analysis & Reporting (`Lux.Web3.Gas.Reporter`)

Provides multi-denomination breakdown and renders clean markdown reports:

```elixir
report = Gas.analyze_cost(%{
  gas_used: 100_000,
  base_fee_gwei: 28.0,
  priority_fee_gwei: 2.0,
  eth_price_usd: 2650.0
})

IO.puts(Lux.Web3.Gas.Reporter.to_markdown(report))
```

---

## 4. Using `Lux.Prisms.GasOptimizerPrism` in Agent Workflows

Autonomous Lux agents can leverage the `GasOptimizerPrism` directly inside Beams or conversational tasks:

```elixir
{:ok, plan} = Lux.Prisms.GasOptimizerPrism.run(%{
  action: "optimize",
  payload: %{
    estimated_gas: 80_000,
    action_type: :swap,
    slippage_percentage: 1.2,
    eth_price_usd: 2500.0
  }
})
```

---

## 5. Testing & Verification

Comprehensive test suites are available under `test/unit/lux/web3/gas/` and `test/unit/lux/prisms/gas_optimizer_prism_test.exs`.

Run the test suite via Mix:

```bash
mix test test/unit/lux/web3/gas/
mix test test/unit/lux/prisms/gas_optimizer_prism_test.exs
```
