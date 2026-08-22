# Technical Design Specification: Binance Integration for Lux (`Lux.Binance`)

## 1. Executive Summary & Scope

This specification defines the architectural design, module layout, data schemas, authentication mechanics, rate-limiting interceptors, and test plan for integrating **Binance (Spot & Futures)** into the **Lux Agent Framework in Elixir**.

### Core Objectives
1. **Unified Authentication (`Lux.Binance.Auth`)**: Provide HMAC-SHA256 signing for REST and WebSocket endpoints using `X-MBX-APIKEY` headers and timestamped request payloads.
2. **REST Clients (`Lux.Binance.Client`)**: Configurable HTTP layer built on `Req` targeting both Binance Spot (`api.binance.com`) and Futures (`fapi.binance.com`), with testnet support.
3. **Resilient Rate Limiting (`Lux.Binance.RateLimiter`)**: Interceptor/GenServer module for tracking API weights (`x-mbx-used-weight-1m`, `x-fapi-used-weight-1m`) and automatically respecting HTTP `429` status backoffs and `Retry-After` headers.
4. **Data Lenses (`Lux.Lenses.Binance.*`)**:
   - `BinanceTickerPriceLens`: Multi-market ticker price fetcher (Spot & Futures).
   - `BinanceExchangeInfoLens`: Market rules, trading pairs, and symbol precision fetcher.
5. **Action Prisms (`Lux.Prisms.Binance.*`)**:
   - **Spot**: `BinanceSpotAccountPrism`, `BinanceSpotOrderPrism`, `BinanceSpotCancelOrderPrism`, `BinanceSpotOpenOrdersPrism`.
   - **Futures**: `BinanceFuturesAccountPrism`, `BinanceFuturesOrderPrism`, `BinanceFuturesPositionPrism`, `BinanceFuturesCancelOrderPrism`.
6. **WebSocket Streaming (`Lux.Binance.WebSocket.*`)**: Stream client for market streams (`kline`, `depth`, `ticker`, `trade`) and `listenKey` lifecycle management for User Data Streams.

---

## 2. Binance API Technical Deep Dive

### 2.1 REST Endpoints Overview

| Market | Security | HTTP Method | Endpoint Path | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Spot** | `NONE` | `GET` | `/api/v3/ticker/price` | Ticker price for symbol(s) |
| **Spot** | `NONE` | `GET` | `/api/v3/exchangeInfo` | Exchange rules, symbols, rate limits |
| **Spot** | `USER_DATA` | `GET` | `/api/v3/account` | Account balances and permissions |
| **Spot** | `TRADE` | `POST` | `/api/v3/order` | Place new spot order |
| **Spot** | `TRADE` | `DELETE` | `/api/v3/order` | Cancel existing spot order |
| **Spot** | `USER_DATA` | `GET` | `/api/v3/openOrders` | Query open spot orders |
| **Futures** | `NONE` | `GET` | `/fapi/v1/ticker/price` | Futures ticker price |
| **Futures** | `NONE` | `GET` | `/fapi/v1/exchangeInfo` | Futures market rules & contract details |
| **Futures** | `USER_DATA` | `GET` | `/fapi/v2/account` | Futures account summary & margin |
| **Futures** | `TRADE` | `POST` | `/fapi/v1/order` | Place new USD-M futures order |
| **Futures** | `USER_DATA` | `GET` | `/fapi/v2/positionRisk` | Futures open position information |
| **Futures** | `TRADE` | `DELETE` | `/fapi/v1/order` | Cancel existing futures order |

### 2.2 Base URLs & Environment Configuration

| Environment | Spot Base URL | Futures Base URL | WS Stream Base URL |
| :--- | :--- | :--- | :--- |
| **Mainnet** | `https://api.binance.com` | `https://fapi.binance.com` | `wss://stream.binance.com:9443/ws` |
| **Testnet** | `https://testnet.binance.vision` | `https://testnet.binancefuture.com` | `wss://testnet.binance.vision/ws` |

### 2.3 Authentication Mechanics (HMAC-SHA256)
Binance endpoints requiring `TRADE` or `USER_DATA` security require:
1. Header `X-MBX-APIKEY`: Set to the user's API Key.
2. Query Parameter `timestamp`: UNIX timestamp in milliseconds (e.g. `1672531199000`).
3. Query Parameter `recvWindow`: Optional window in milliseconds (default: `5000`, max: `60000`) for network latency window check.
4. Parameter `signature`: HMAC-SHA256 digest of the entire query string or request body calculated using the API Secret Key.

```elixir
# Signature generation signature
string_to_sign = URI.encode_query(params_with_timestamp)
signature = :crypto.mac(:hmac, :sha256, secret_key, string_to_sign)
            |> Base.encode16(case: :lower)
```

### 2.4 Rate Limiting & 429 Backoff Strategy

Binance tracks rate limits via HTTP headers returned in responses:
- **Spot Headers**: `x-mbx-used-weight-1m` (Request weight used in current 1-min window), `x-mbx-order-count-10s`, `x-mbx-order-count-1m`.
- **Futures Headers**: `x-fapi-used-weight-1m`, `x-fapi-order-count-1m`.
- **HTTP Status Codes**:
  - `429 Too Many Requests`: Rate limit reached. Consecutive violations result in IP bans.
  - `418 I'm a Teapot`: Auto-ban triggered (duration ranges from 2 minutes to 3 days).
- **Header `Retry-After`**: Integer specifying the backoff wait duration in seconds.

#### Rate Limiter Architecture in Lux (`Lux.Binance.RateLimiter`)
- Uses an internal `GenServer` with an `:ets` table storing weight counters per endpoint category and backoff state (`backoff_until`).
- Standard `Req` plugin/middleware intercepts requests:
  1. **Pre-request Check**: Checks if current system time < `backoff_until`. If so, returns `{:error, {:rate_limited, wait_ms}}` or delays request.
  2. **Post-request Inspection**: Inspects response headers (`x-mbx-used-weight-1m`, `x-fapi-used-weight-1m`). If status is 429 or 418, parses `Retry-After` header (default to 60s if omitted) and updates `backoff_until` state.

---

## 3. Recommended Codebase Directory Layout

```
lib/lux/
├── binance/
│   ├── auth.ex                         # HMAC-SHA256 signing logic
│   ├── client.ex                       # Core HTTP client using Req
│   ├── rate_limiter.ex                 # Rate limiting GenServer & Req middleware
│   ├── web_socket/
│   │   ├── client.ex                   # WebSocket market stream client
│   │   └── user_data_stream.ex         # listenKey manager (Spot & Futures)
│   └── config.ex                       # Configuration helper for Binance API keys
├── integrations/
│   └── binance.ex                      # Core Integration entry point & request settings
├── lenses/
│   └── binance/
│       ├── ticker_price_lens.ex        # BinanceTickerPriceLens
│       └── exchange_info_lens.ex       # BinanceExchangeInfoLens
└── prisms/
    └── binance/
        ├── spot_account_prism.ex       # BinanceSpotAccountPrism
        ├── spot_order_prism.ex         # BinanceSpotOrderPrism
        ├── spot_cancel_order_prism.ex  # BinanceSpotCancelOrderPrism
        ├── spot_open_orders_prism.ex   # BinanceSpotOpenOrdersPrism
        ├── futures_account_prism.ex    # BinanceFuturesAccountPrism
        ├── futures_order_prism.ex      # BinanceFuturesOrderPrism
        ├── futures_position_prism.ex   # BinanceFuturesPositionPrism
        └── futures_cancel_order_prism.ex # BinanceFuturesCancelOrderPrism
```

---

## 4. Detailed Module Architecture & Specifications

### 4.1 `Lux.Binance.Auth`
- **Module Path**: `lib/lux/binance/auth.ex`
- **Responsibility**: Compute HMAC-SHA256 signatures and attach timestamps & `X-MBX-APIKEY` headers.

```elixir
defmodule Lux.Binance.Auth do
  @moduledoc """
  Authentication helper for Binance Spot & Futures REST/WebSocket APIs.
  """

  @doc """
  Signs a map or keyword list of params with HMAC-SHA256 using secret_key.
  Appends timestamp (if missing) and signature.
  """
  @spec sign_params(map() | keyword(), String.t(), integer()) :: map()
  def sign_params(params, secret_key, recv_window \\ 5000)

  @doc """
  Generates lower-case hex HMAC-SHA256 signature for given binary payload.
  """
  @spec hmac_sha256(String.t(), String.t()) :: String.t()
  def hmac_sha256(secret_key, payload)
end
```

### 4.2 `Lux.Binance.RateLimiter`
- **Module Path**: `lib/lux/binance/rate_limiter.ex`
- **Responsibility**: GenServer & `Req` middleware for tracking request weights and handling HTTP 429/418 retry backoffs.

```elixir
defmodule Lux.Binance.RateLimiter do
  @moduledoc """
  Rate Limiter GenServer and Req middleware for Binance API limits.
  Tracks weight usage (x-mbx-used-weight-1m, x-fapi-used-weight-1m) and backoff windows.
  """
  use GenServer

  @doc "Req middleware function to attach to Req.Request steps"
  @spec attach(Req.Request.t()) :: Req.Request.t()
  def attach(request)

  @doc "Checks if current process/node is currently rate limited"
  @spec check_rate_limit(atom()) :: :ok | {:error, {:rate_limited, integer()}}
  def check_rate_limit(market_type \\ :spot)

  @doc "Records response headers and status codes to update rate limit state"
  @spec record_response(map(), map()) :: :ok
  def record_response(headers, response_info)
end
```

### 4.3 `Lux.Binance.Client`
- **Module Path**: `lib/lux/binance/client.ex`
- **Responsibility**: Base HTTP client wrapper built on `Req`. Handles URL routing, header composition, signing, rate limiter integration, and error normalization.

```elixir
defmodule Lux.Binance.Client do
  @moduledoc """
  HTTP Client for Binance REST API calls.
  """

  @type market_type :: :spot | :futures
  @type method :: :get | :post | :put | :delete

  @spec request(method(), market_type(), String.t(), map(), keyword()) ::
          {:ok, map() | list()} | {:error, term()}
  def request(method, market_type, path, params \\ %{}, opts \\ [])
end
```

---

## 5. Lens Specifications

### 5.1 `BinanceTickerPriceLens` (`Lux.Lenses.Binance.TickerPriceLens`)
- **Module Path**: `lib/lux/lenses/binance/ticker_price_lens.ex`
- **Description**: Fetches real-time price ticker data for a symbol or all symbols on Spot or Futures.
- **Endpoints**:
  - Spot: `GET /api/v3/ticker/price`
  - Futures: `GET /fapi/v1/ticker/price`
- **Schema**:
```elixir
schema: %{
  type: :object,
  properties: %{
    market_type: %{
      type: :string,
      enum: ["spot", "futures"],
      default: "spot",
      description: "Market type: 'spot' or 'futures'"
    },
    symbol: %{
      type: :string,
      description: "Trading pair symbol (e.g. 'BTCUSDT'). Omit for all symbols."
    }
  }
}
```
- **Example Usage**:
```elixir
Lux.Lenses.Binance.TickerPriceLens.focus(%{market_type: "spot", symbol: "BTCUSDT"})
# Returns: {:ok, %{symbol: "BTCUSDT", price: "95120.50"}}
```

### 5.2 `BinanceExchangeInfoLens` (`Lux.Lenses.Binance.ExchangeInfoLens`)
- **Module Path**: `lib/lux/lenses/binance/exchange_info_lens.ex`
- **Description**: Fetches exchange rules, rate limits, precision requirements, and active symbols.
- **Endpoints**:
  - Spot: `GET /api/v3/exchangeInfo`
  - Futures: `GET /fapi/v1/exchangeInfo`
- **Schema**:
```elixir
schema: %{
  type: :object,
  properties: %{
    market_type: %{
      type: :string,
      enum: ["spot", "futures"],
      default: "spot",
      description: "Market type: 'spot' or 'futures'"
    },
    symbol: %{
      type: :string,
      description: "Optional specific symbol to query (e.g. 'ETHUSDT')"
    }
  }
}
```

---

## 6. Prism Specifications

### 6.1 Spot Prisms

#### 1. `BinanceSpotAccountPrism` (`Lux.Prisms.Binance.SpotAccountPrism`)
- **Module Path**: `lib/lux/prisms/binance/spot_account_prism.ex`
- **Description**: Retrieves Spot account details, permissions, asset balances, and trade status.
- **Endpoint**: `GET /api/v3/account` (SIGNED, `USER_DATA`)
- **Input Schema**: `%{}`, accepts optional `:recv_window`.
- **Output Schema**: Maps containing balances (`asset`, `free`, `locked`), permissions, account type.

#### 2. `BinanceSpotOrderPrism` (`Lux.Prisms.Binance.SpotOrderPrism`)
- **Module Path**: `lib/lux/prisms/binance/spot_order_prism.ex`
- **Description**: Places a new spot order (LIMIT, MARKET, STOP_LOSS_LIMIT, TAKE_PROFIT_LIMIT, etc.).
- **Endpoint**: `POST /api/v3/order` (SIGNED, `TRADE`)
- **Input Schema**:
```elixir
input_schema: %{
  type: :object,
  properties: %{
    symbol: %{type: :string, description: "Trading pair (e.g. 'BTCUSDT')"},
    side: %{type: :string, enum: ["BUY", "SELL"]},
    type: %{type: :string, enum: ["LIMIT", "MARKET", "STOP_LOSS", "STOP_LOSS_LIMIT", "TAKE_PROFIT", "TAKE_PROFIT_LIMIT", "LIMIT_MAKER"]},
    timeInForce: %{type: :string, enum: ["GTC", "IOC", "FOK"]},
    quantity: %{type: :number, description: "Order quantity in base asset"},
    price: %{type: :number, description: "Order price (required for LIMIT orders)"},
    stopPrice: %{type: :number, description: "Stop trigger price"},
    newClientOrderId: %{type: :string, description: "Custom unique order ID"}
  },
  required: ["symbol", "side", "type"]
}
```

#### 3. `BinanceSpotCancelOrderPrism` (`Lux.Prisms.Binance.SpotCancelOrderPrism`)
- **Module Path**: `lib/lux/prisms/binance/spot_cancel_order_prism.ex`
- **Description**: Cancels an active spot order.
- **Endpoint**: `DELETE /api/v3/order` (SIGNED, `TRADE`)
- **Input Schema**:
```elixir
input_schema: %{
  type: :object,
  properties: %{
    symbol: %{type: :string, description: "Trading pair (e.g. 'BTCUSDT')"},
    orderId: %{type: :integer, description: "Binance order ID"},
    origClientOrderId: %{type: :string, description: "Client custom order ID"}
  },
  required: ["symbol"]
}
```

#### 4. `BinanceSpotOpenOrdersPrism` (`Lux.Prisms.Binance.SpotOpenOrdersPrism`)
- **Module Path**: `lib/lux/prisms/binance/spot_open_orders_prism.ex`
- **Description**: Fetches all current open spot orders.
- **Endpoint**: `GET /api/v3/openOrders` (SIGNED, `USER_DATA`)
- **Input Schema**: `%{}`, optional `symbol`.

---

### 6.2 Futures Prisms

#### 1. `BinanceFuturesAccountPrism` (`Lux.Prisms.Binance.FuturesAccountPrism`)
- **Module Path**: `lib/lux/prisms/binance/futures_account_prism.ex`
- **Description**: Retrieves USD-M Futures account info, total margin, wallet balance, and open positions summary.
- **Endpoint**: `GET /fapi/v2/account` (SIGNED, `USER_DATA`)

#### 2. `BinanceFuturesOrderPrism` (`Lux.Prisms.Binance.FuturesOrderPrism`)
- **Module Path**: `lib/lux/prisms/binance/futures_order_prism.ex`
- **Description**: Places a new USD-M Futures order.
- **Endpoint**: `POST /fapi/v1/order` (SIGNED, `TRADE`)
- **Input Schema**:
```elixir
input_schema: %{
  type: :object,
  properties: %{
    symbol: %{type: :string, description: "Futures trading pair (e.g. 'BTCUSDT')"},
    side: %{type: :string, enum: ["BUY", "SELL"]},
    positionSide: %{type: :string, enum: ["BOTH", "LONG", "SHORT"], default: "BOTH"},
    type: %{type: :string, enum: ["LIMIT", "MARKET", "STOP", "STOP_MARKET", "TAKE_PROFIT", "TAKE_PROFIT_MARKET", "TRAILING_STOP_MARKET"]},
    timeInForce: %{type: :string, enum: ["GTC", "IOC", "FOK", "GTX"]},
    quantity: %{type: :number, description: "Order quantity"},
    price: %{type: :number, description: "Limit price"},
    stopPrice: %{type: :number, description: "Trigger stop price"},
    reduceOnly: %{type: :boolean, default: false},
    newClientOrderId: %{type: :string}
  },
  required: ["symbol", "side", "type"]
}
```

#### 3. `BinanceFuturesPositionPrism` (`Lux.Prisms.Binance.FuturesPositionPrism`)
- **Module Path**: `lib/lux/prisms/binance/futures_position_prism.ex`
- **Description**: Queries current position risk details, entry price, mark price, leverage, and unrealized PnL.
- **Endpoint**: `GET /fapi/v2/positionRisk` (SIGNED, `USER_DATA`)
- **Input Schema**: `%{}`, optional `symbol`.

#### 4. `BinanceFuturesCancelOrderPrism` (`Lux.Prisms.Binance.FuturesCancelOrderPrism`)
- **Module Path**: `lib/lux/prisms/binance/futures_cancel_order_prism.ex`
- **Description**: Cancels active futures order.
- **Endpoint**: `DELETE /fapi/v1/order` (SIGNED, `TRADE`)
- **Input Schema**: `%{}`, `symbol` required, `orderId` or `origClientOrderId`.

---

## 7. WebSocket Streaming Architecture

### 7.1 `Lux.Binance.WebSocket.Client`
- **Module Path**: `lib/lux/binance/web_socket/client.ex`
- **Purpose**: Low-latency WebSocket connections for market streams (`<symbol>@aggTrade`, `<symbol>@kline_<interval>`, `<symbol>@depth5`).
- **Features**: Automatic reconnection with exponential backoff, ping/pong frame handling (Binance requires ping responses every 3 mins), multi-stream subscription (`/stream?streams=...`).

### 7.2 `Lux.Binance.WebSocket.UserDataStream`
- **Module Path**: `lib/lux/binance/web_socket/user_data_stream.ex`
- **Purpose**: Manages `listenKey` generation (`POST /api/v3/userDataStream` or `/fapi/v1/userDataStream`) and periodic keepalive (`PUT` request every 30 minutes) to maintain active private account updates.

---

## 8. ExUnit Test Architecture & Mock Strategy

### 8.1 Test Layout
```
test/
├── unit/
│   └── lux/
│       └── binance/
│           ├── auth_test.exs
│           ├── rate_limiter_test.exs
│           └── client_test.exs
└── integration/
    └── lux/
        ├── lenses/
        │   └── binance/
        │       ├── ticker_price_lens_test.exs
        │       └── exchange_info_lens_test.exs
        └── prisms/
            └── binance/
                ├── spot_account_prism_test.exs
                ├── spot_order_prism_test.exs
                ├── spot_cancel_order_prism_test.exs
                ├── spot_open_orders_prism_test.exs
                ├── futures_account_prism_test.exs
                ├── futures_order_prism_test.exs
                ├── futures_position_prism_test.exs
                └── futures_cancel_order_prism_test.exs
```

### 8.2 Testing Strategy with `Req.Test`
Unit tests intercept HTTP requests via `Req.Test` adapter without making external HTTP calls:
- Test 200 OK responses with standard Binance JSON payload mocks.
- Test 429 Rate Limit backoff logic by returning `status: 429` with `retry-after: "5"`.
- Test HMAC signature verification by verifying `query` parameters inside `Req.Test` handler.

---

## 9. Implementation Roadmap

1. **Phase 1**: Core Infrastructure (`Lux.Binance.Auth`, `Lux.Binance.RateLimiter`, `Lux.Binance.Client`).
2. **Phase 2**: Lenses (`BinanceTickerPriceLens`, `BinanceExchangeInfoLens`).
3. **Phase 3**: Spot Prisms (`SpotAccountPrism`, `SpotOrderPrism`, `SpotCancelOrderPrism`, `SpotOpenOrdersPrism`).
4. **Phase 4**: Futures Prisms (`FuturesAccountPrism`, `FuturesOrderPrism`, `FuturesPositionPrism`, `FuturesCancelOrderPrism`).
5. **Phase 5**: WebSocket Stream & ListenKey Manager (`Lux.Binance.WebSocket.Client`, `UserDataStream`).
6. **Phase 6**: ExUnit Test Suite & Verification.
