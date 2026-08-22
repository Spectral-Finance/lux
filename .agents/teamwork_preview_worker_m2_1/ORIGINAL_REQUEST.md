## 2026-08-06T23:44:10Z
You are Worker 1 for Bounty #84 (Binance Exchange Integration in Elixir for Lux framework).

Working directory: /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_worker_m2_1
Project root: /home/Konor1743/Operacion Dolar/lux/lux

Read design specifications from:
- /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_2/analysis.md
- /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_3/analysis.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Tasks:
1. Implement core authentication module `Lux.Binance.Auth` in `lib/lux/binance/auth.ex` providing HMAC-SHA256 signing for query string and body parameters, adding `timestamp`, `recvWindow`, and `X-MBX-APIKEY` headers.
2. Implement rate limiter middleware `Lux.Binance.RateLimiter` in `lib/lux/binance/rate_limiter.ex` tracking weight headers (`x-mbx-used-weight-1m`, `x-fapi-used-weight-1m`), intercepting HTTP 429 / 418 status codes, and parsing `Retry-After` headers for backoff / retries.
3. Implement core REST HTTP client `Lux.Binance.Client` in `lib/lux/binance/client.ex` using `Req` for Spot (`api.binance.com`) and Futures (`fapi.binance.com`), with testnet support.
4. Implement WebSocket client `Lux.Binance.WebSocket.Client` and `Lux.Binance.WebSocket.UserDataStream` in `lib/lux/binance/web_socket/` for market streams and listenKey lifecycle management.
5. Implement Market Data Lenses under `lib/lux/lenses/binance/`:
   - `BinanceTickerPriceLens` (`lib/lux/lenses/binance/ticker_price_lens.ex`)
   - `BinanceExchangeInfoLens` (`lib/lux/lenses/binance/exchange_info_lens.ex`)
   - Provide `@moduledoc` and `@doc` with clear Elixir examples.
6. Implement Spot Trading Prisms under `lib/lux/prisms/binance/`:
   - `BinanceSpotAccountPrism` (`spot_account_prism.ex`)
   - `BinanceSpotOrderPrism` (`spot_order_prism.ex`)
   - `BinanceSpotCancelOrderPrism` (`spot_cancel_order_prism.ex`)
   - `BinanceSpotOpenOrdersPrism` (`spot_open_orders_prism.ex`)
   - Provide `@moduledoc` and `@doc` with clear Elixir examples.
7. Implement Futures Trading Prisms under `lib/lux/prisms/binance/`:
   - `BinanceFuturesAccountPrism` (`futures_account_prism.ex`)
   - `BinanceFuturesOrderPrism` (`futures_order_prism.ex`)
   - `BinanceFuturesPositionPrism` (`futures_position_prism.ex`)
   - `BinanceFuturesCancelOrderPrism` (`futures_cancel_order_prism.ex`)
   - Provide `@moduledoc` and `@doc` with clear Elixir examples.
8. Create ExUnit test suite under `test/lux/binance/` (or `test/unit/lux/binance/`):
   - HMAC-SHA256 mathematical signature test vector against official Binance spec.
   - Programmatic 429 rate limit backoff and retry test.
   - Unit tests for all Lenses and Prisms with HTTP mocks.
9. Verify compilation and tests:
   - Run `mix compile --warnings-as-errors` in /home/Konor1743/Operacion Dolar/lux/lux.
   - Run `mix test` in /home/Konor1743/Operacion Dolar/lux/lux.
10. Write `changes.md` and `handoff.md` in /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_worker_m2_1 and notify parent (ID: 2d585f15-4d46-404c-a7a1-200756202c3a) with build/test results.
