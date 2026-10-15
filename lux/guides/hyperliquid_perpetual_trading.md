# Hyperliquid Integration and Perpetual Trading

Lux provides a unified Hyperliquid perpetual futures trading engine (`Lux.Web3.Exchanges.Hyperliquid` and `Lux.Prisms.Web3.HyperliquidPrism`) designed for autonomous agent order execution, leverage and margin management, and real-time liquidation protection.

## Core Capabilities

1. **Perpetual Universe & L2 Orderbook Feed**: Queries perpetual asset specifications (max leverage, maintenance margin bps, hourly funding rates, mark/oracle prices) and L2 bid/ask depth.
2. **Multi-Type Order Execution**: Supports `:market`, `:limit` (`:gtc`, `:ioc`, `:alo`), `:trigger` (stop-loss / take-profit with `reduce_only`), and `:twap` (sliced time-weighted execution) orders.
3. **Leverage & Margin Management**: Configures per-asset leverage up to asset maximums and manages `:cross` and `:isolated` margin balances.
4. **Position Analytics & Liquidation Protection**: Calculates live unrealized/realized PnL, ROE%, maintenance margin ratios, exact liquidation prices, and automated 50% emergency deleveraging when mark price approaches liquidation thresholds.

## Usage Example

```elixir
alias Lux.Web3.Exchanges.Hyperliquid

# 1. Configure 15x isolated leverage on ETH
{:ok, _} = Hyperliquid.set_leverage(wallet, "ETH", 15, :isolated)

# 2. Open a 4 ETH long position and attach a reduce-only stop-loss trigger order
{:ok, fill} = Hyperliquid.place_order(wallet, %{coin: "ETH", side: :buy, size: 4.0, order_type: :market})
{:ok, sl} = Hyperliquid.place_order(wallet, %{
  coin: "ETH",
  side: :sell,
  size: 4.0,
  order_type: :trigger,
  trigger_price: 2_820.0,
  reduce_only: true
})

# 3. Monitor position PnL and run automated liquidation protection
{:ok, state} = Hyperliquid.get_user_state(wallet)
{:ok, risk_report} = Hyperliquid.assess_risk_and_protect(wallet, auto_protect: true)
```
