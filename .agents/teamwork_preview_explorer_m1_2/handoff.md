# Handoff Report: Milestone 1 Binance Exchange Integration Design

## 1. Observation
- **Project Structure**: Investigated `/home/Konor1743/Operacion Dolar/lux/lux` code layout. `mix.exs` uses Elixir `~> 1.18` with dependencies `:req` (`~> 0.5.0`), `:bandit`, `:ethers`, `:ex_secp256k1`, `:hammer` (test), `:mock`, etc.
- **Existing Integrations & Patterns**:
  - `lib/lux/lens.ex` lines 1-200: Standard macro `use Lux.Lens` supporting `before_focus/1`, `after_focus/1`, `focus/2`, and `authenticate/1`.
  - `lib/lux/prism.ex` lines 1-245: Standard macro `use Lux.Prism` with `input_schema`, `output_schema`, and `handler/2`.
  - Hyperliquid implementation (`lib/lux/prisms/hyperliquid/hyperliquid_execute_order_prism.ex`): Provides pattern for exchange order prisms using configuration in `Lux.Config`.
- **Binance API Requirements**:
  - **Spot REST API Base URL**: `https://api.binance.com` (Testnet: `https://testnet.binance.vision`)
  - **Futures REST API Base URL**: `https://fapi.binance.com` (Testnet: `https://testnet.binancefuture.com`)
  - **WebSocket Base Stream URLs**: `wss://stream.binance.com:9443/ws`, `wss://fstream.binance.com/ws`
  - **Authentication**: HMAC-SHA256 signature using API Secret over query string / request body payload appended with UNIX ms `timestamp` and optional `recvWindow`. Sent with header `X-MBX-APIKEY`.
  - **Rate Limiting**: Monitored via response headers `x-mbx-used-weight-1m` (Spot) and `x-fapi-used-weight-1m` (Futures). Errors return status `429` (Rate limit exceeded) or `418` (IP Ban) with `Retry-After` header (seconds).

## 2. Logic Chain
1. **HTTP Client Choice**: Lux relies heavily on `Req` (`~> 0.5.0`). Therefore, `Lux.Binance.Client` should wrap `Req` to provide seamless HTTP capabilities, custom steps, and environment switching (`:spot` vs `:futures`, `:mainnet` vs `:testnet`).
2. **Rate Limiting Middleware**: To handle 429 status codes and `Retry-After` backoffs without crashing workflows, a dedicated `Lux.Binance.RateLimiter` module operating as a `Req` step + `GenServer` tracking weight usage and backoff timestamps is optimal.
3. **Lenses vs Prisms Separation**:
   - Data-fetching read operations (`BinanceTickerPriceLens`, `BinanceExchangeInfoLens`) inherit from `Lux.Lens`.
   - Stateful action operations (`BinanceSpotAccountPrism`, `BinanceSpotOrderPrism`, `BinanceSpotCancelOrderPrism`, `BinanceSpotOpenOrdersPrism`, `BinanceFuturesAccountPrism`, `BinanceFuturesOrderPrism`, `BinanceFuturesPositionPrism`, `BinanceFuturesCancelOrderPrism`) inherit from `Lux.Prism`.
4. **Testing Strategy**: Mocking external HTTP endpoints using `Req.Test` allows fast ExUnit test execution without requiring live API keys.

## 3. Caveats
- No live Binance API credentials were used during this read-only investigation phase.
- WebSocket stream connection handling for User Data Streams requires maintaining `listenKey` keepalives every 30 minutes.

## 4. Conclusion
The Binance Exchange integration design is fully specified in `/home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2/analysis.md`. The design fulfills all requirements for HMAC-SHA256 Auth, Rate Limiting (Weight & Raw Requests, 429/418 handling, `Retry-After`), WebSockets, 2 Lenses, and 8 Prisms.

## 5. Verification Method
1. Read `/home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2/analysis.md` to review module interfaces, schemas, and file layout.
2. Run `mix compile` in `/home/Konor1743/Operacion Dolar/lux/lux` to verify codebase compilation state prior to implementation.
