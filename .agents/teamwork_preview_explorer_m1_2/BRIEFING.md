# BRIEFING — 2026-08-06T23:43:06Z

## Mission
Analyze Binance Spot & Futures REST/WS APIs, Auth, and Rate Limiting, and design module structure under `Lux.Binance` with Lenses and Prisms for Bounty #84 Milestone 1.

## 🔒 My Identity
- Archetype: explorer
- Roles: Explorer 2
- Working directory: /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2
- Original parent: 2d585f15-4d46-404c-a7a1-200756202c3a
- Milestone: Milestone 1 - Binance Integration Design

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Scope: Binance Spot & Futures REST APIs, WS APIs, HMAC-SHA256 Auth, Rate Limiting, Lenses, Prisms

## Current Parent
- Conversation ID: 2d585f15-4d46-404c-a7a1-200756202c3a
- Updated: 2026-08-06T23:43:06Z

## Investigation State
- **Explored paths**: `mix.exs`, `PROJECT.md`, `lib/lux.ex`, `lib/lux/lens.ex`, `lib/lux/prism.ex`, `lib/lux/config.ex`, `lib/lux/integrations/discord.ex`, `lib/lux/lenses/allora/get_inference.ex`, `lib/lux/prisms/hyperliquid/hyperliquid_execute_order_prism.ex`.
- **Key findings**: Binance API specs analyzed for Spot & Futures REST, WebSockets, HMAC-SHA256 Auth, Rate Limiter middleware, 2 Lenses, and 8 Prisms.
- **Unexplored areas**: None for Milestone 1 design.

## Key Decisions Made
- Module namespace established under `Lux.Binance`, `Lux.Lenses.Binance.*`, and `Lux.Prisms.Binance.*`.
- Auth module designed (`Lux.Binance.Auth`) for HMAC-SHA256 timestamped signatures.
- Rate Limiter designed (`Lux.Binance.RateLimiter`) with `Req` interceptor and GenServer state tracking `x-mbx-used-weight-1m`, `429`/`418` status codes, and `Retry-After` header.
- Designed 2 Lenses (`BinanceTickerPriceLens`, `BinanceExchangeInfoLens`).
- Designed 4 Spot Prisms (`BinanceSpotAccountPrism`, `BinanceSpotOrderPrism`, `BinanceSpotCancelOrderPrism`, `BinanceSpotOpenOrdersPrism`).
- Designed 4 Futures Prisms (`BinanceFuturesAccountPrism`, `BinanceFuturesOrderPrism`, `BinanceFuturesPositionPrism`, `BinanceFuturesCancelOrderPrism`).

## Artifact Index
- /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2/ORIGINAL_REQUEST.md — Initial task request
- /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2/BRIEFING.md — Working memory index
- /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2/analysis.md — Design specification for Binance integration
- /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2/handoff.md — 5-component handoff report
