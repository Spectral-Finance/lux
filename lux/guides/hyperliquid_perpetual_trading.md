# Hyperliquid Integration and Perpetual Trading

`Lux.Prisms.Hyperliquid.PerpExecutionPrism` enables autonomous perpetual trading on Hyperliquid L1 with:
- Order placement (`Gtc`, `Ioc`, `Alo`, `reduce_only`) and leverage validation (`1x`–`50x`)
- Real-time unrealized PnL, effective equity, maintenance margin, and exact liquidation price tracking
- Automated liquidation protection (`liquidation_protection_plan/2`)
