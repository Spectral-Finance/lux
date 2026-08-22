# Lux Codebase Analysis & Architecture Report: Binance Exchange Integration (Milestone 1)

## Executive Summary

This report presents an architectural analysis of the **Lux framework** (`/home/Konor1743/Operacion Dolar/lux/lux`) to guide the design and implementation of the **Binance Exchange Integration** (Bounty #84). The investigation covers dependency management, core Lux primitives (`Lux.Lens`, `Lux.Prism`), HTTP/REST & WebSocket paradigms, compiler configuration, testing conventions, and a concrete architecture blueprint for the upcoming Binance integration.

---

## 1. Dependency Analysis

The project dependencies are managed via `mix.exs` and resolved in `mix.lock`.

### Key Dependencies & Usage

| Dependency | Version Spec | Current Status in `mix.exs` / `mix.lock` | Architectural Role |
| :--- | :--- | :--- | :--- |
| **`req`** | `~> 0.5.0` | Top-level in `mix.exs` | Standard HTTP client for REST requests across all Lenses and Integrations (Allora, Discord, Telegram, Etherscan). Provides plug support for mock testing via `Req.Test`. |
| **`jason`** | Transitive | In `mix.lock` (via `req`, `ex_json_schema`, `ethereumex`) | High-performance JSON parser/encoder used throughout the framework. |
| **`websockex`** | `~> 0.4.3` | In `mix.lock` (via `ethereumex`), NOT top-level in `mix.exs` | Pure Elixir WebSocket client for real-time streaming connections. Required for Binance market data and user data streams. |
| **`ex_json_schema`** | `~> 0.10.2` | Top-level in `mix.exs` | Validates input and output schemas defined in Prisms and Lenses. |
| **`dotenvy`** | `~> 1.1.0` | Top-level in `mix.exs` (`:dev`, `:test`) | Parses `.envrc` environment configuration files in `config/runtime.exs`. |
| **`venomous`** | `~> 0.7.5` | Top-level in `mix.exs` | Erlang/Python process manager for Python bridge execution. |
| **`bandit`** | `~> 1.0` | Top-level in `mix.exs` | HTTP web server implementation. |
| **`credo` / `styler`** | `~> 1.7` / `~> 1.3` | Top-level in `mix.exs` (`:dev`, `:test`) | Code quality, style enforcement, and static analysis tools. |
| **`dialyxir`** | `~> 1.4.5` | Top-level in `mix.exs` (`:dev`) | Dialyzer static type checker (configured with PLT path `priv/plts/`). |

### Recommendation for `mix.exs`
- Promote `{:websockex, "~> 0.4.3"}` to a top-level dependency in `mix.exs` to explicitly manage WebSocket streaming dependencies for Binance data streams.

---

## 2. Core Architectural Conventions: Prisms vs. Lenses

Lux establishes a clean separation of concerns between data retrieval (**Lenses**) and action execution (**Prisms**).

```
                      +-------------------+
                      |   Lux Framework   |
                      +---------+---------+
                                |
             +------------------+------------------+
             |                                     |
  +----------v----------+               +----------v----------+
  |      Lux.Lens       |               |      Lux.Prism      |
  | (Read-Only Queries) |               | (Mutations/Actions) |
  +----------+----------+               +----------+----------+
             |                                     |
  * HTTP GET / REST Query               * Order Placement / Cancel
  * Data Normalization                  * Business Logic Execution
  * `focus/2` & `after_focus/1`         * `run/2` & `handler/2`
```

### 2.1 Lux.Lens (Read-Only Data Fetching)
- **Module**: `lib/lux/lens.ex`
- **Purpose**: Declarative read-only data fetching from external HTTP/REST endpoints or custom data providers.
- **Key Characteristics**:
  - Uses `use Lux.Lens` macro with configuration (`name`, `description`, `url`, `method`, `headers`, `auth`, `schema`).
  - Implements optional `before_focus/1` callback to transform/format request parameters (e.g. url path interpolation or query params).
  - Implements `after_focus/1` callback to parse, sanitize, and format HTTP responses into standardized `{:ok, result}` or `{:error, reason}` tuples.
  - Automatically executes HTTP requests via `Req.new(...) |> Req.request(...)` under the hood.
  - Includes standard authentication helpers (`authenticate/1`) supporting `:api_key`, `:basic`, `:oauth`, and `:custom` functions.

### 2.2 Lux.Prism (Action & State Mutation Execution)
- **Module**: `lib/lux/prism.ex`
- **Purpose**: Encapsulated, composable units of business logic, state mutation, order execution, or multi-step processing.
- **Key Characteristics**:
  - Uses `use Lux.Prism` macro with schema definitions (`name`, `description`, `input_schema`, `output_schema`, `examples`).
  - Implements `@callback handler(input :: any(), context :: any()) :: {:ok, any()} | {:error, any()}`.
  - Executed via `PrismModule.run(input, context)` or `Lux.Prism.run(PrismModule, input, context)`.
  - Used for side-effecting operations like placing buy/sell orders, cancelling orders, running calculations, or interacting with HTTP client libraries.

---

## 3. Code Layout & Project Structure

The project follows a standard Elixir / Mix application structure:

```
lux/
├── config/
│   ├── config.exs          # Base application config & python process settings
│   └── runtime.exs         # Environment-based API keys & accounts setup (via Dotenvy)
├── lib/
│   └── lux/
│       ├── agent.ex        # Agent definitions
│       ├── beam.ex         # Workflow orchestration engine
│       ├── config.ex       # Central configuration helper (Lux.Config)
│       ├── lens.ex         # Lux.Lens macro & runner
│       ├── prism.ex        # Lux.Prism macro & runner
│       ├── integrations/   # HTTP API clients (Discord, Telegram, Allora)
│       ├── lenses/         # Concrete Lens modules (Allora, Discord, Etherscan)
│       └── prisms/         # Concrete Prism modules (Hyperliquid, Discord, Telegram)
├── test/
│   ├── test_helper.exs     # ExUnit setup, UnitAPICase (Req.Test plug setup), IntegrationCase
│   ├── unit/               # Unit tests tagged with @moduletag :unit
│   └── integration/        # Integration tests tagged with @moduletag :integration
├── mix.exs                 # Dependencies, aliases, compiler config, package info
└── mix.lock                # Locked dependency tree
```

### Compiler & Quality Configuration
- **Elixir Version**: `~> 1.18`
- **Compilation Output**: Clean compilation with `mix compile`. `warnings_as_errors` can be passed via command line (`mix compile --warnings-as-errors`) or configured in `mix.exs` `elixirc_options`.
- **Test Aliases**:
  - `mix test.unit`: Runs `test --include unit`
  - `mix test.integration`: Runs `test --include integration`

---

## 4. Architectural Proposals for Binance Exchange Integration

### 4.1 Binance HTTP Client (`Lux.Integrations.Binance.Client`)
Location: `lib/lux/integrations/binance/client.ex`

- Uses `Req` for low-level REST calls to Binance Spot API (default base URL: `https://api.binance.com`).
- Features HMAC SHA256 signature generation for authenticated endpoints:
  - Generates `timestamp` (current Unix timestamp in milliseconds).
  - Signs query parameters/body using `HMAC-SHA256` with `binance_api_secret`.
  - Passes `X-MBX-APIKEY` header with `binance_api_key`.
- Supports test plug injection via `Req.Test` (following `Lux.Integrations.Discord.Client` pattern).

```elixir
defmodule Lux.Integrations.Binance.Client do
  @moduledoc """
  HTTP client for Binance REST API endpoints.
  """
  require Logger

  @default_endpoint "https://api.binance.com"

  def request(method, path, opts \\ %{}) do
    api_key = opts[:api_key] || Lux.Config.binance_api_key()
    api_secret = opts[:api_secret] || Lux.Config.binance_api_secret()
    base_url = opts[:base_url] || Lux.Config.binance_api_url() || @default_endpoint

    signed? = Map.get(opts, :signed, false)
    params = Map.get(opts, :params, %{})

    {headers, params} = if signed? do
      timestamp = System.system_time(:millisecond)
      query_params = Map.put(params, :timestamp, timestamp)
      query_string = URI.encode_query(query_params)
      signature = :crypto.mac(:hmac, :sha256, api_secret, query_string) |> Base.encode16(case: :lower)

      headers = [{"X-MBX-APIKEY", api_key}]
      {headers, Map.put(query_params, :signature, signature)}
    else
      {[], params}
    end

    # Send request using Req
    [
      method: method,
      url: base_url <> path,
      headers: headers,
      params: if(method == :get, do: params, else: %{}),
      json: if(method != :get, do: params, else: nil)
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp handle_response({:ok, %{status: 200, body: body}}), do: {:ok, body}
  defp handle_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp handle_response({:error, reason}), do: {:error, reason}
end
```

### 4.2 Binance Configuration Extension (`Lux.Config`)
Location: `lib/lux/config.ex` & `config/runtime.exs`

- Add keys in `config/runtime.exs`:
  ```elixir
  config :lux, :accounts,
    binance_api_key: env!("BINANCE_API_KEY", :string!, required: false),
    binance_api_secret: env!("BINANCE_API_SECRET", :string!, required: false),
    binance_api_url: env!("BINANCE_API_URL", :string!, "https://api.binance.com"),
    binance_ws_url: env!("BINANCE_WS_URL", :string!, "wss://stream.binance.com:9443/ws")
  ```
- Expose getter functions in `Lux.Config`:
  - `binance_api_key/0`
  - `binance_api_secret/0`
  - `binance_api_url/0`
  - `binance_ws_url/0`

### 4.3 Proposed Lenses & Prisms Structure

```
lib/lux/
├── lenses/
│   └── binance/
│       ├── fetch_ticker_lens.ex       # Ticker price / 24hr stats
│       ├── fetch_orderbook_lens.ex    # Orderbook depth
│       ├── fetch_klines_lens.ex       # Candlestick / Kline data
│       ├── fetch_account_info_lens.ex # Account balances & permissions (signed)
│       └── fetch_open_orders_lens.ex  # Current open orders (signed)
└── prisms/
    └── binance/
        ├── create_order_prism.ex      # Limit / Market order creation
        ├── cancel_order_prism.ex      # Single order cancellation
        └── cancel_all_orders_prism.ex # Batch cancellation for symbol
```

### 4.4 Binance WebSocket Client (`Lux.Integrations.Binance.WebSocketClient`)
Location: `lib/lux/integrations/binance/websocket_client.ex`

- Uses `WebSockex` GenServer behaviour.
- Handles real-time stream subscription (`wss://stream.binance.com:9443/ws/<stream_name>`).
- Implements `handle_connect/2`, `handle_frame/2`, and dispatch mechanism for event broadcasts.

---

## 5. Testing & Verification Strategy

1. **Unit Testing (`UnitAPICase`)**:
   - Utilize `Req.Test` plug mocking for all Binance REST Lenses and Prisms.
   - Test HMAC signature generation with known test vectors.
   - Verify error response handling (HTTP 400/401/429/500).
2. **Integration Testing (`IntegrationCase`)**:
   - Live network tests against Binance Public APIs (e.g., ticker / server time) tagged with `@moduletag :integration`.
3. **Static Analysis & Formatting**:
   - Run `mix compile --warnings-as-errors`
   - Run `mix format --check-formatted`
   - Run `mix credo --strict`

---
*Report compiled by Explorer 1 for Bounty #84 Milestone 1.*
