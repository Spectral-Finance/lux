# Coinbase Advanced Trade & Exchange Integration Suite

Production-grade, fully tested integration suite for **Coinbase Advanced Trade** and **Coinbase Exchange** built for the **Spectral Finance Lux Framework** ($750 Bounty).

---

## 1. Architecture Overview

The integration suite is structured as a two-layer hybrid architecture:

```
+-----------------------------------------------------------------------------------+
|                            ELIXIR AGENTIC LAYER                                   |
|  - Lux.Agents.CoinbaseTradingAgent (Autonomous Multi-Modal Agent)                 |
|  - Lux.Beams.Coinbase.CoinbaseTradingBeam (Workflow & Pipeline Orchestrator)      |
|  - Lux.Signals.Coinbase.{TickerSignal, OrderSignal, PortfolioSignal}              |
|  - Lux.Schemas.Coinbase.{TickerSchema, OrderSchema, PortfolioSchema}              |
|  - Lux.Lenses.Coinbase.{MarketDataLens, AccountLens, OrderLens}                   |
|  - Lux.Prisms.Coinbase.{RestClientPrism, WebsocketFeedPrism,                      |
|                         OrderExecutionPrism, PortfolioSyncPrism}                  |
|  - Lux.Integrations.Coinbase (Configuration, Dual Auth, Sandbox / Prod toggles)   |
+-----------------------------------------------------------------------------------+
                                        |  (Lux.Python / Venomous)
                                        v
+-----------------------------------------------------------------------------------+
|                            PYTHON CORE ENGINE                                     |
|  - types.py: Enums & Strict Pydantic V2 Models (Order, Ticker, Candle, etc.)     |
|  - auth.py: Dual Auth (CDP ECDSA P-256 JWT ES256 & Legacy HMAC-SHA256)            |
|  - rest.py: Production CoinbaseRestClient (Session pooling, retries, errors)      |
|  - rate_limiter.py: Thread-safe Token Bucket (Public & Private) + Jitter Backoff  |
|  - websocket.py: CoinbaseWebSocketManager (Background loop, auto-reconnect)       |
|  - portfolio.py: PortfolioTracker & Risk Limit Engine (PnL, Allocations, Limits)   |
|  - pipeline.py: Unified CoinbasePipeline Orchestrator                             |
+-----------------------------------------------------------------------------------+
```

---

## 2. Python Core Implementation (`lux/priv/python/lux/coinbase/`)

### 2.1 Types & Models (`types.py`)
- **Strict Enums**:
  - `OrderSide`: `BUY`, `SELL`
  - `OrderType`: `MARKET`, `LIMIT`, `STOP_LIMIT`, `STOP`
  - `OrderStatus`: `OPEN`, `FILLED`, `CANCELLED`, `EXPIRED`, `FAILED`, `PENDING`
  - `TimeInForce`: `GTC`, `IOC`, `FOK`, `GTD`
  - `Granularity`: `ONE_MINUTE` (60s), `FIVE_MINUTE` (300s), `FIFTEEN_MINUTE` (900s), `ONE_HOUR` (3600s), `SIX_HOUR` (21600s), `ONE_DAY` (86400s)
  - `ChannelType`: `ticker`, `heartbeats`, `candles`, `status`, `user`, `level2`
- **Pydantic V2 Models**:
  - `Product`: ID, base/quote currencies, increments, status, limits.
  - `Order`: Order ID, client order ID, side, price, size, filled status, fees.
  - `Candle`: OHLCV candlestick representation.
  - `Ticker`: 24h volume, high, low, best bid, best ask, mid price.
  - `AccountBalance`: Available, hold, and total balance per currency.
  - `PortfolioSummary`: USD valuation, allocations, 24h realized/unrealized PnL.
  - `OrderPlacementRequest`: Generates compliant Coinbase Advanced Trade order configurations.
  - `CancelOrderResponse`: Batch cancellation status and reasons.

### 2.2 Dual Authentication Handler (`auth.py`)
- **Modern CDP API Keys**:
  - Signs ECDSA P-256 JWTs using `ES256` algorithm.
  - Claims: `iss="cdp"`, `sub=api_key_name`, `nbf`, `exp`, `uri="METHOD host/path"`.
  - Injects `Authorization: Bearer <jwt>` and `CB-ACCESS-KEY`.
- **Legacy API Keys**:
  - Computes HMAC-SHA256 signature on `timestamp + method + path + body`.
  - Injects `CB-ACCESS-KEY`, `CB-ACCESS-SIGN`, `CB-ACCESS-TIMESTAMP`, `CB-ACCESS-PASSPHRASE`.
- **WebSocket Auth**:
  - Generates WS authentication payloads for authorized streaming channels (e.g. `user`).

### 2.3 Production REST Client (`rest.py`)
- `CoinbaseRestClient`:
  - Connection pooling with `requests.Session` and `HTTPAdapter`.
  - Automatic status error wrapping:
    - `CoinbaseAPIError` (base)
    - `CoinbaseAuthError` (401 / 403)
    - `CoinbaseRateLimitError` (429 with `Retry-After` parsing)
    - `CoinbaseNotFoundError` (404)
  - Endpoints:
    - `get_products()`, `get_product(product_id)`
    - `get_candles(product_id, granularity, start, end)`
    - `get_best_bid_ask(product_ids)`
    - `get_market_trades(product_id, limit)`
    - `get_accounts()`, `get_account(account_uuid)`, `get_portfolio_breakdown()`
    - `create_order(request)`, `cancel_orders(order_ids)`, `get_order(order_id)`, `list_orders()`
    - `get_transaction_summary()`

### 2.4 Thread-Safe Token Bucket Rate Limiter (`rate_limiter.py`)
- **Token Bucket algorithm**:
  - Public endpoints: 10 req/s, burst 15 tokens.
  - Private / Trading endpoints: 30 req/s, burst 50 tokens.
- **Backoff & Jitter**:
  - Full jitter exponential backoff on HTTP 429 and transient errors.
  - Dynamic `Retry-After` header extraction.
- **Context Manager**: `with rate_limiter.limit("private"): ...`

### 2.5 Real-Time WebSocket Manager (`websocket.py`)
- `CoinbaseWebSocketManager`:
  - Dedicated background worker thread with `asyncio` event loop.
  - Non-blocking synchronous interface for easy scripting and Elixir bridge execution.
  - Subscriptions: `ticker`, `level2`, `user`, `heartbeats`, `candles`, `status`.
  - Automatic reconnection with exponential backoff supervisor.
  - Heartbeat tracking and callback dispatcher.

### 2.6 Portfolio Tracker & Risk Management (`portfolio.py`)
- `PortfolioTracker`:
  - Mark-to-market total portfolio valuation in USD.
  - Asset allocation percentages.
  - Realized and unrealized 24h PnL calculations.
  - Pre-trade risk enforcement:
    - Max single-asset concentration percentage limit.
    - Max position dollar limit.
    - Available balance sufficiency checks.

### 2.7 Pipeline Orchestrator (`pipeline.py`)
- `CoinbasePipeline`:
  - Unifies REST client, WebSocket streaming, rate limiter, and portfolio tracker into an integrated interface.
  - `sync_portfolio()`: Fetches balances and updates USD asset valuations.
  - `start_streaming()` / `stop_streaming()`: Manages live feeds and updates portfolio state on incoming ticks.
  - `analyze_market()`: Computes moving averages, 24h changes, high/low spread, and volume.
  - `execute_order()`: Performs pre-trade risk checks before order submission.

---

## 3. Elixir Integration Layer (`lux/lib/lux/`)

### 3.1 Integration Module
- `Lux.Integrations.Coinbase`:
  - API credentials, CDP keys, and environment resolution.
  - Sandbox toggle (`sandbox?`) and base URLs.

### 3.2 Lenses
- `Lux.Lenses.Coinbase.MarketDataLens`: Focuses on products, ticker snapshots, and candles.
- `Lux.Lenses.Coinbase.AccountLens`: Focuses on account balances and portfolio breakdowns.
- `Lux.Lenses.Coinbase.OrderLens`: Focuses on open orders, order history, and fee rates.

### 3.3 Prisms
- `Lux.Prisms.Coinbase.RestClientPrism`: Dispatches REST operations.
- `Lux.Prisms.Coinbase.WebsocketFeedPrism`: Configures WebSocket subscriptions.
- `Lux.Prisms.Coinbase.OrderExecutionPrism`: Executes orders with risk evaluation.
- `Lux.Prisms.Coinbase.PortfolioSyncPrism`: Syncs portfolio state and allocation metrics.

### 3.4 Schemas & Signals
- `Lux.Schemas.Coinbase.TickerSchema` / `Lux.Signals.Coinbase.TickerSignal`
- `Lux.Schemas.Coinbase.OrderSchema` / `Lux.Signals.Coinbase.OrderSignal`
- `Lux.Schemas.Coinbase.PortfolioSchema` / `Lux.Signals.Coinbase.PortfolioSignal`
- `Lux.Schemas.Coinbase` registry module.

### 3.5 Beam
- `Lux.Beams.Coinbase.CoinbaseTradingBeam`: Multi-step trading beam coordinating portfolio synchronization, live market check, risk branching, and order execution.

### 3.6 Agent
- `Lux.Agents.CoinbaseTradingAgent`: Autonomous agent with market surveillance, risk enforcement, and order execution capabilities.

---

## 4. Test Verification

All unit test suites are fully automated via `pytest`:

```bash
cd lux/priv/python
python -m pytest tests/coinbase -v
```

### Test Coverage Results
- `tests/coinbase/test_auth.py`: HMAC-SHA256 signature, timestamp injection, CDP ES256 JWT claims, WS auth payloads.
- `tests/coinbase/test_rest.py`: Mocked REST endpoints for products, orders, candles, accounts, fees, 401/404/429 error handling.
- `tests/coinbase/test_rate_limiter.py`: Token bucket capacity, refill, multithreaded concurrency, jitter backoff.
- `tests/coinbase/test_websocket.py`: Subscription management, heartbeat tracking, message dispatching.
- `tests/coinbase/test_portfolio.py`: Balance valuation, trade fill PnL tracking, risk limits.
- `tests/coinbase/test_pipeline.py`: End-to-end sync, market analysis, safe order execution, streaming lifecycle.
- `tests/coinbase/test_types.py`: Enum helpers, Pydantic V2 validations, payload formatting.

**Result**: 43 passed in 1.74s (100% pass rate).
