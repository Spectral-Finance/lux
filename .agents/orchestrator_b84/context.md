# Technical Context: Binance Exchange Integration (Bounty #84)

## Project Root & Environment
- Workspace Root: `/home/Konor1743/Operacion Dolar/lux/lux`
- Elixir Framework: Lux (`Spectral-Finance/lux`)
- Target Elixir version: Standard Mix project configuration
- Primary HTTP Client: `Req` or standard Lux HTTP abstraction
- Primary WebSocket Client: WebSockets / WebSockex / Mint
- Testing Framework: `ExUnit` with HTTP Mocks (`Req.Test` or custom mock adapter)

## Key Technical Requirements
1. **REST API & HMAC-SHA256 Auth**:
   - Spot base URL: `https://api.binance.com`
   - Futures base URL: `https://fapi.binance.com`
   - HMAC-SHA256 signatures generated over query string / POST body using secret key.
   - Header: `X-MBX-APIKEY` for API key.

2. **Market Data Lenses**:
   - `BinanceTickerPriceLens`: Real-time ticker price streaming via WebSockets.
   - `BinanceExchangeInfoLens`: REST/WebSocket exchange info lens.
   - Resilience & auto-reconnect strategy on WebSocket drop.

3. **Trading Systems (Prisms)**:
   - Spot: `BinanceSpotAccountPrism`, `BinanceSpotOrderPrism`, `BinanceSpotCancelOrderPrism`, `BinanceSpotOpenOrdersPrism`.
   - Futures: `BinanceFuturesAccountPrism`, `BinanceFuturesOrderPrism`, `BinanceFuturesPositionPrism`, `BinanceFuturesCancelOrderPrism`.

4. **Rate Limiting (Strict Interceptor)**:
   - Respect weight limits and raw request rate limits.
   - Handle 429 status code and `Retry-After` header with backoff and retry queueing.

5. **ExUnit Tests & Documentation**:
   - 100% compilation with zero warnings (`mix compile --warnings-as-errors`).
   - Full `@moduledoc` and `@doc` on all Prisms and Lenses with Elixir code examples.
   - Programmatic 429 rate limit backoff/retry test.
   - Exact mathematical HMAC-SHA256 unit test per Binance specification.
