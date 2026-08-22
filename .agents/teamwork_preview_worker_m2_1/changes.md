# Summary of Changes - Binance Exchange Integration (Bounty #84)

## Core Binance Infrastructure (`lib/lux/binance/`)
1. **`lib/lux/binance/auth.ex` (`Lux.Binance.Auth`)**
   - Implemented HMAC-SHA256 signing for query string and body parameters.
   - Added automatic timestamping (`timestamp`), receive windows (`recvWindow`, default 5000ms), and `X-MBX-APIKEY` headers.
   - Verified against official Binance documentation mathematical signature test vector.

2. **`lib/lux/binance/rate_limiter.ex` (`Lux.Binance.RateLimiter`)**
   - Implemented rate limiter GenServer and `Req` middleware for Binance API rate limit compliance.
   - Tracked used weight headers (`x-mbx-used-weight-1m`, `x-fapi-used-weight-1m`).
   - Intercepted HTTP 429 (Rate Limit Exceeded) and HTTP 418 (Teapot / Ban) status codes.
   - Parsed `Retry-After` response headers for automatic programmatic backoff.

3. **`lib/lux/binance/client.ex` (`Lux.Binance.Client`)**
   - Implemented REST HTTP client built on `Req` targeting Spot (`api.binance.com`) and Futures (`fapi.binance.com`).
   - Added testnet URL routing (`testnet.binancevision.com`, `testnet.binancefuture.com`).
   - Integrated authentication, signing, and rate limiter middleware.

4. **`lib/lux/binance/web_socket/client.ex` (`Lux.Binance.WebSocket.Client`)**
   - Implemented WebSocket client for market streams (`<symbol>@trade`, `<symbol>@ticker`, `<symbol>@kline`, `<symbol>@depth`).
   - Implemented multi-stream subscription, ping/pong frame handling, auto-reconnection, and Lux Signal emission.

5. **`lib/lux/binance/web_socket/user_data_stream.ex` (`Lux.Binance.WebSocket.UserDataStream`)**
   - Implemented `listenKey` lifecycle management (`POST`, `PUT` keep-alive every 30 minutes, `DELETE` close) for private account and execution streams.

## Market Data Lenses (`lib/lux/lenses/binance/`)
1. **`lib/lux/lenses/binance/ticker_price_lens.ex` (`Lux.Lenses.Binance.TickerPriceLens`)**
   - Multi-market ticker price fetcher for Spot and Futures.
   - Complete `@moduledoc`, `@doc`, schema, and Elixir examples.

2. **`lib/lux/lenses/binance/exchange_info_lens.ex` (`Lux.Lenses.Binance.ExchangeInfoLens`)**
   - Exchange rules, rate limits, active symbols, and precision fetcher for Spot and Futures.
   - Complete `@moduledoc`, `@doc`, schema, and Elixir examples.

## Spot Trading Prisms (`lib/lux/prisms/binance/`)
1. `lib/lux/prisms/binance/spot_account_prism.ex` (`Lux.Prisms.Binance.SpotAccountPrism`) - Retrieves Spot balances and permissions.
2. `lib/lux/prisms/binance/spot_order_prism.ex` (`Lux.Prisms.Binance.SpotOrderPrism`) - Places new Spot orders (LIMIT, MARKET, STOP_LOSS, etc.).
3. `lib/lux/prisms/binance/spot_cancel_order_prism.ex` (`Lux.Prisms.Binance.SpotCancelOrderPrism`) - Cancels active Spot orders.
4. `lib/lux/prisms/binance/spot_open_orders_prism.ex` (`Lux.Prisms.Binance.SpotOpenOrdersPrism`) - Queries open Spot orders.

## Futures Trading Prisms (`lib/lux/prisms/binance/`)
1. `lib/lux/prisms/binance/futures_account_prism.ex` (`Lux.Prisms.Binance.FuturesAccountPrism`) - Retrieves USD-M Futures account info, margin, and balances.
2. `lib/lux/prisms/binance/futures_order_prism.ex` (`Lux.Prisms.Binance.FuturesOrderPrism`) - Places new USD-M Futures orders (LIMIT, MARKET, STOP, etc.).
3. `lib/lux/prisms/binance/futures_position_prism.ex` (`Lux.Prisms.Binance.FuturesPositionPrism`) - Queries position risk, mark price, leverage, and unrealized PnL.
4. `lib/lux/prisms/binance/futures_cancel_order_prism.ex` (`Lux.Prisms.Binance.FuturesCancelOrderPrism`) - Cancels active USD-M Futures orders.

## Core Framework Enhancements
1. **`lib/lux/lens.ex` (`Lux.Lens`)**
   - Added `focus: 2` to `defoverridable` list to allow custom lenses to override `focus/2` cleanly.

## ExUnit Test Suite
1. `test/lux/binance/auth_test.exs` - Official Binance mathematical signature test vector & key header unit tests.
2. `test/lux/binance/rate_limiter_test.exs` - Weight tracking, HTTP 429/418 intercept, `Retry-After` backoff unit tests.
3. `test/lux/binance/client_test.exs` - REST client requests, testnet routing, signed POST, HTTP error responses.
4. `test/lux/binance/web_socket_test.exs` - WebSocket market stream subscriptions, frame parsing, `listenKey` lifecycle.
5. `test/lux/lenses/binance/ticker_price_lens_test.exs` - Spot and Futures ticker price lens unit tests.
6. `test/lux/lenses/binance/exchange_info_lens_test.exs` - Spot and Futures exchange info lens unit tests.
7. `test/lux/prisms/binance/spot_prisms_test.exs` - Spot account, order creation, order cancellation, and open orders unit tests.
8. `test/lux/prisms/binance/futures_prisms_test.exs` - Futures account, order creation, position risk, and order cancellation unit tests.

## Verification
- `mix compile --warnings-as-errors`: PASSED (0 warnings, 0 errors).
- `mix test`: PASSED (1398 tests, 0 failures).
