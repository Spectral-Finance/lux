# Uniswap V3 Liquidity Management in Lux

This guide covers the Uniswap V3 Prisms, Lens, and Beam for automated concentrated liquidity management in Lux:

- `Lux.Lenses.UniswapV3.PoolMonitorLens`: Captures pool `slot0` price, TWAP oracle price, and realized volatility.
- `Lux.Prisms.UniswapV3.RangeOptimizerPrism`: Computes optimal volatility-adjusted tick ranges and protects rebalances against MEV sandwiching via TWAP divergence checks.
- `Lux.Prisms.UniswapV3.PositionManagerPrism`: Implements Uniswap V3 tick math (`1.0001^tick`), concentrated liquidity calculations, capital efficiency metrics, and position mint/rebalance actions.
- `Lux.Prisms.UniswapV3.FeeCollectorPrism`: Evaluates uncollected fees against gas costs and computes optimal 50/50 auto-compounding splits.
- `Lux.Prisms.UniswapV3.IlProtectionPrism`: Quantifies concentrated Impermanent Loss (IL) vs HODL and calculates delta-neutral hedge sizing.
- `Lux.Beams.UniswapV3.LiquidityManagementBeam`: Combines all components into a single autonomous workflow.
