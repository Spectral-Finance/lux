# Uniswap V3 Integration Guide

## Position Manager
```elixir
{:ok, pid} = PositionManager.start_link()

# Create concentrated liquidity position
{:ok, pos} = PositionManager.create_position(pid, %{
  token0: "WETH", token1: "USDC", fee_tier: 3000,
  price_lower: 1800.0, price_upper: 2200.0, amount0: 1.0, amount1: 2000.0
})

# Monitor health
{:ok, health} = PositionManager.health_check(pid, pos.id)
# %{in_range: true, needs_rebalance: false, impermanent_loss_estimate: 0.5}

# Rebalance
PositionManager.rebalance(pid, pos.id, %{price_lower: 1900.0, price_upper: 2300.0})

# Collect fees
{:ok, fees} = PositionManager.collect_fees(pid, pos.id)

# Portfolio overview
{:ok, summary} = PositionManager.portfolio_summary(pid)
```

## Price Optimizer
```elixir
# Fee tier recommendation
{:ok, rec} = PriceOptimizer.recommend_fee_tier(%{volatility: :medium, correlation: 0.5})

# Range optimization
{:ok, range} = PriceOptimizer.optimize_range(%{current_price: 2000.0, strategy: :balanced})

# IL calculation
{:ok, il} = PriceOptimizer.calculate_il(100.0, 150.0)
```
