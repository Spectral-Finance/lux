## 2026-08-06T23:43:06Z
You are Explorer 2 for Milestone 1 of Bounty #84 (Binance Exchange Integration in Elixir for Lux framework).

Working directory: /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2
Project root: /home/Konor1743/Operacion Dolar/lux/lux

Your Task:
1. Analyze all requirements for Binance Spot & Futures REST APIs, WebSockets, HMAC-SHA256 Auth, and Rate Limiting (Weight & Raw Requests, 429 status code handling, Retry-After header).
2. Design the module structure under `Lux.Binance` (or `Lux.Integrations.Binance`):
   - Auth: HMAC-SHA256 signing logic
   - REST Clients: Spot & Futures (`api.binance.com` & `fapi.binance.com`)
   - Rate Limiter: Middleware/Interceptor for 429 backoff
   - Lenses: `BinanceTickerPriceLens`, `BinanceExchangeInfoLens`
   - Prisms:
     * Spot: `BinanceSpotAccountPrism`, `BinanceSpotOrderPrism`, `BinanceSpotCancelOrderPrism`, `BinanceSpotOpenOrdersPrism`
     * Futures: `BinanceFuturesAccountPrism`, `BinanceFuturesOrderPrism`, `BinanceFuturesPositionPrism`, `BinanceFuturesCancelOrderPrism`
3. Output your design spec in /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2/analysis.md and write handoff.md.
4. Send a message to parent (ID: 2d585f15-4d46-404c-a7a1-200756202c3a) with a summary of findings.
