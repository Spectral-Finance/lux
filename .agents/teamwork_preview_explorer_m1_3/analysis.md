# Comprehensive Testing Strategy for Binance Exchange Integration (Bounty #84 - Milestone 1)

## Executive Summary

This report establishes the technical testing strategy for the Binance Exchange Integration in Elixir for the Spectral-Finance Lux framework. As part of Milestone 1, this document provides the architectural specification for testing all core components of the Binance integration:
1. **Spot and Futures HTTP Response Mocking** via native `Req.Test` adapters and canned fixtures.
2. **Programmatic 429 Rate Limit Backoff & Retry Verification** without incurring test suite delays.
3. **HMAC-SHA256 Signature Test Vector Verification** using official Binance API documentation specs.
4. **Resilient WebSocket Lens Testing** covering reconnection, heartbeats, and UserData `listenKey` management using local `Bandit` WebSocket doubles and unit adapters.

---

## 1. Analysis of Existing Lux Test Architecture

### 1.1 Test Suite Structure and Helper Modules

Investigation of `/home/Konor1743/Operacion Dolar/lux/lux/test` reveals a clean separation between unit and integration tests:

* **`test/test_helper.exs`**:
  * Configures `ExUnit.start(exclude: [:skip, :integration, :unit])`.
  * Defines `UnitAPICase` (`ExUnit.CaseTemplate`), tagging tests with `@moduletag :unit` and setting up default `Req.Test` plug environments for APIs (e.g. OpenAI, Anthropic, Etherscan, Discord).
  * Defines `IntegrationCase` (`ExUnit.CaseTemplate`), tagging tests with `@moduletag :integration`.
* **`guides/testing.md`**:
  * Specifies test execution commands: `mix test.unit` for unit tests, `mix test.integration` for live integration tests using real API keys stored in `test.override.envrc`.
  * Emphasizes test isolation and warns against running unit and integration tests simultaneously due to environment plug configurations.

### 1.2 HTTP Client and Mocking Infrastructure (`Req` & `Req.Test`)

Lux uses `Req` (`~> 0.5.0`) as its primary HTTP client (`lib/lux/lens.ex`, `lib/lux/llm/*.ex`).
`Req.Test` is built directly into `Req` 0.5.0, offering process-isolated mocking backed by process ownership (`Req.Test.Ownership`).

#### Core `Req.Test` Patterns in Lux:
1. **Application Env Configuration**:
   ```elixir
   Application.put_env(:lux, Lux.Lenses.Binance, plug: {Req.Test, Lux.Lenses.Binance})
   ```
2. **Expectation and Stub Registration**:
   ```elixir
   Req.Test.expect(Lux.Lenses.Binance, fn conn ->
     assert conn.method == "GET"
     assert conn.request_path == "/api/v3/ticker/price"
     Req.Test.json(conn, %{"symbol" => "BTCUSDT", "price" => "65000.00"})
   end)
   ```
3. **Verification on Exit**:
   ```elixir
   setup do
     Req.Test.verify_on_exit!()
   end
   ```

This architecture allows concurrent ExUnit tests (`async: true`) without process state bleed.

---

## 2. HTTP Response Mocking Strategy (Spot & Futures APIs)

### 2.1 Endpoint Categorization

Binance Exchange features two distinct REST API domains:
* **Spot REST API**: Base URL `https://api.binance.com` (Prefix `/api/v3/`).
  * Endpoints: Order creation (`POST /api/v3/order`), Ticker price (`GET /api/v3/ticker/price`), Order book depth (`GET /api/v3/depth`), Account info (`GET /api/v3/account`).
* **USD-M / COIN-M Futures REST API**: Base URL `https://fapi.binance.com` (Prefix `/fapi/v1/` or `/fapi/v2/`).
  * Endpoints: Futures order (`POST /fapi/v1/order`), Position risk (`GET /fapi/v2/positionRisk`), Account balance (`GET /fapi/v2/balance`), Mark price (`GET /fapi/v1/premiumIndex`).

### 2.2 Reusable Fixtures Module (`Lux.Test.Support.BinanceFixtures`)

To avoid test code duplication, create a shared test fixture module at `test/support/binance_fixtures.ex`:

```elixir
defmodule Lux.Test.Support.BinanceFixtures do
  @moduledoc """
  Standardized HTTP response payloads for Binance Spot and Futures APIs.
  """

  def spot_ticker_price_response(symbol \\ "BTCUSDT", price \\ "65000.00") do
    %{"symbol" => symbol, "price" => price}
  end

  def spot_order_response(opts \\ []) do
    %{
      "symbol" => Keyword.get(opts, :symbol, "BTCUSDT"),
      "orderId" => Keyword.get(opts, :order_id, 2831919),
      "clientOrderId" => "6gCrw2k3y1b2c3d4e5f6a7",
      "transactTime" => 1507725176595,
      "price" => Keyword.get(opts, :price, "65000.00"),
      "origQty" => Keyword.get(opts, :qty, "1.00000000"),
      "executedQty" => "1.00000000",
      "cummulativeQuoteQty" => "65000.00000000",
      "status" => Keyword.get(opts, :status, "FILLED"),
      "timeInForce" => "GTC",
      "type" => Keyword.get(opts, :type, "LIMIT"),
      "side" => Keyword.get(opts, :side, "BUY")
    }
  end

  def futures_position_risk_response(symbol \\ "BTCUSDT") do
    [
      %{
        "entryPrice" => "0.00000",
        "marginType" => "isolated",
        "isAutoAddMargin" => "false",
        "isolatedMargin" => "0.00000000",
        "leverage" => "20",
        "liquidationPrice" => "0",
        "markPrice" => "65120.50000000",
        "maxNotionalValue" => "20000000",
        "positionAmt" => "0.000",
        "symbol" => symbol,
        "unRealizedProfit" => "0.00000000",
        "positionSide" => "BOTH"
      }
    ]
  end

  def error_response(code, msg) do
    %{"code" => code, "msg" => msg}
  end
end
```

### 2.3 Unit Testing Mock Setup with `Req.Test`

For unit tests, `Lux.Lenses.Binance` or individual sub-lenses (`Lux.Lenses.Binance.Spot.Order`, `Lux.Lenses.Binance.Futures.PositionRisk`) will retrieve HTTP options from `:lux` app config:

```elixir
defmodule Lux.Lenses.Binance.Spot.OrderTest do
  use UnitAPICase, async: true
  alias Lux.Test.Support.BinanceFixtures

  setup do
    Req.Test.verify_on_exit!()
  end

  test "successfully places a Spot LIMIT BUY order" do
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/v3/order"
      assert conn.req_headers |> Enum.into(%{}) |> Map.get("x-mbx-apikey") == "test_api_key"
      
      # Verify query string or body contains expected fields and signature
      assert conn.query_string =~ "symbol=BTCUSDT"
      assert conn.query_string =~ "signature="

      Req.Test.json(conn, BinanceFixtures.spot_order_response())
    end)

    params = %{
      symbol: "BTCUSDT",
      side: "BUY",
      type: "LIMIT",
      quantity: "1.0",
      price: "65000.00",
      api_key: "test_api_key",
      secret_key: "test_secret_key"
    }

    assert {:ok, %{"status" => "FILLED", "orderId" => 2831919}} =
             Lux.Lenses.Binance.Spot.Order.focus(params)
  end
end
```

---

## 3. Programmatic Rate Limit Backoff & Retry Testing (HTTP 429)

### 3.1 Binance Rate Limit Mechanics
Binance enforces strict rate limits:
* **HTTP Status**: `429 Too Many Requests` (Request rate limit exceeded) or `418 I'm a Teapot` (IP banned due to repeated 429 violations).
* **Response Headers**:
  * `x-mbx-used-weight-1m`: Request weight used in current 1-minute window.
  * `retry-after`: Integer seconds to back off before retrying.
* **Response Body**: `%{"code" => -1003, "msg" => "Too many requests; current limit is 1200 requests per minute."}`.

### 3.2 Backoff Strategy in Client Architecture
The Binance integration must implement exponential backoff with jitter or honor the `retry-after` header value.
In `Req`, retries are configured via `retry: :safe_transient` or a custom step:

```elixir
def retry_delay(retry_count, response, opts) do
  case response do
    %{headers: headers} ->
      headers
      |> Enum.find(fn {k, _v} -> String.downcase(k) == "retry-after" end)
      |> case do
        {_, seconds} -> String.to_integer(seconds) * opts[:delay_multiplier]
        nil -> calculate_exponential_backoff(retry_count, opts)
      end
    _ ->
      calculate_exponential_backoff(retry_count, opts)
  end
end
```

To ensure tests execute in milliseconds rather than waiting full seconds, pass a test `delay_multiplier: 1` (milliseconds) or inject a test time provider.

### 3.3 Programmatic 429 Test Implementation

Using sequential `Req.Test.expect/3` calls, we simulate a initial 429 failure followed by successful retry recovery:

```elixir
defmodule Lux.Lenses.Binance.RateLimitTest do
  use UnitAPICase, async: true

  setup do
    Req.Test.verify_on_exit!()
  end

  test "retries on 429 rate limit error and succeeds on subsequent attempt" do
    # 1st attempt: 429 Too Many Requests
    Req.Test.expect(Lux.Lens, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("retry-after", "1")
      |> Plug.Conn.put_resp_header("x-mbx-used-weight-1m", "1205")
      |> Req.Test.json(%{"code" => -1003, "msg" => "Too many requests"}, status: 429)
    end)

    # 2nd attempt (Retry): 200 OK
    Req.Test.expect(Lux.Lens, fn conn ->
      assert conn.request_path == "/api/v3/ticker/price"
      Req.Test.json(conn, %{"symbol" => "ETHUSDT", "price" => "3500.00"})
    end)

    # Invoke lens with fast retry option
    opts = [retry_backoff_ms: 10, max_retries: 3]
    assert {:ok, %{"price" => "3500.00"}} =
             Lux.Lenses.Binance.Spot.TickerPrice.focus(%{symbol: "ETHUSDT"}, opts)
  end

  test "fails with rate limit error after max retries are exhausted" do
    # Expect max_retries + 1 (e.g. 3 attempts total)
    Req.Test.expect(Lux.Lens, 3, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("retry-after", "1")
      |> Req.Test.json(%{"code" => -1003, "msg" => "Too many requests"}, status: 429)
    end)

    opts = [retry_backoff_ms: 10, max_retries: 2]
    assert {:error, %{status: 429, code: -1003}} =
             Lux.Lenses.Binance.Spot.TickerPrice.focus(%{symbol: "ETHUSDT"}, opts)
  end
end
```

---

## 4. HMAC-SHA256 Signature Test Vector Strategy

### 4.1 Signature Specification
Binance REST API signed endpoints require requests to carry a hex-encoded HMAC-SHA256 signature generated over the request payload using the user's Secret Key.

* **Formula**:
  $$\text{signature} = \text{HexEncode}\left(\text{HMAC-SHA256}\left(\text{secret\_key}, \text{query\_string}\right)\right)$$
* **Header Requirement**: `X-MBX-APIKEY: <api_key>`
* **Mandatory Parameters**: `timestamp` (millisecond Unix epoch) and optional `recvWindow` (default `5000` ms).

### 4.2 Official Binance Test Vectors (From Binance API Docs)

The unit test suite must validate against the exact canonical test vector provided in official Binance API documentation:

#### Official Vector 1 (GET / Query Parameters):
* **Secret Key**: `"NhqPtMDL5cvBxT3a65KSTBmUzaw9M6PZ18fLiNFZw9z86St0695BWkTxzYD6dAe3"`
* **Payload String**: `"symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559"`
* **Expected HMAC-SHA256 Hex Signature**:
  `"c822ea44717eee0003010b9cae43486304d9c490a074092b774f26bfa9f12503"`

#### Official Vector 2 (POST / Form-Urlencoded or Query Parameters):
* **Secret Key**: `"NhqPtMDL5cvBxT3a65KSTBmUzaw9M6PZ18fLiNFZw9z86St0695BWkTxzYD6dAe3"`
* **Payload String**: `"symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559"`
* **Expected Hex Signature**:
  `"c822ea44717eee0003010b9cae43486304d9c490a074092b774f26bfa9f12503"`

### 4.3 Signature Unit Test Implementation (`test/unit/lux/lenses/binance/signer_test.exs`)

```elixir
defmodule Lux.Lenses.Binance.SignerTest do
  use UnitCase, async: true
  alias Lux.Lenses.Binance.Signer

  @binance_secret "NhqPtMDL5cvBxT3a65KSTBmUzaw9M6PZ18fLiNFZw9z86St0695BWkTxzYD6dAe3"

  describe "sign/2" do
    test "matches official Binance documentation test vector exactly" do
      query_string =
        "symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559"

      expected_signature =
        "c822ea44717eee0003010b9cae43486304d9c490a074092b774f26bfa9f12503"

      signature = Signer.sign(query_string, @binance_secret)
      assert signature == expected_signature
    end

    test "correctly builds signed query string from parameter map" do
      params = %{
        symbol: "LTCBTC",
        side: "BUY",
        type: "LIMIT",
        timeInForce: "GTC",
        quantity: "1",
        price: "0.1",
        recvWindow: 5000,
        timestamp: 1499827319559
      }

      signed_params = Signer.sign_params(params, @binance_secret)

      assert signed_params[:signature] ==
               "c822ea44717eee0003010b9cae43486304d9c490a074092b774f26bfa9f12503"
    end

    test "handles parameter ordering and url encoding consistently" do
      params = %{"symbol" => "BTCUSDT", "timestamp" => 1600000000000}
      secret = "secret_key"

      sig1 = Signer.sign("symbol=BTCUSDT&timestamp=1600000000000", secret)
      sig2 = Signer.sign_params(params, secret)[:signature]

      assert sig1 == sig2
      assert String.match?(sig1, ~r/^[a-f0-9]{64}$/)
    end
  end
end
```

---

## 5. Resilient WebSocket Lens Testing Strategy

### 5.1 Binance WebSocket Streams Architecture
Binance stream endpoints:
* Spot Market Streams: `wss://stream.binance.com:9443/ws/<stream>` (e.g. `btcusdt@trade`, `btcusdt@ticker`, `btcusdt@depth`).
* Futures Market Streams: `wss://fstream.binance.com/ws/<stream>`.
* User Data Stream: Private execution/account updates requiring dynamic `listenKey` initialization via HTTP POST `/api/v3/userDataStream` and keep-alive updates every 30 minutes via HTTP PUT.

### 5.2 Test Double Architecture: Local `Bandit` WS Server vs Client Test Adapter

To test WebSocket lenses with high confidence, speed, and resilience without external network dependencies:

1. **Local WebSocket Test Server (`Bandit`)**:
   `Bandit` is already listed in `mix.exs` (`{:bandit, "~> 1.0"}`).
   We can start a local Bandit server on port `0` (ephemeral) running a custom `WebSock` handler during integration/unit testing to verify real WebSockets over loopback (`127.0.0.1`).

2. **In-Memory Client Test Adapter (`WebSockEx` Test Plug)**:
   For ultra-fast unit testing, abstract the connection transport so tests can push synthetic frames directly into the lens callback handlers (`handle_frame/2`).

```elixir
defmodule Lux.Test.Support.BinanceWSServer do
  @moduledoc """
  Minimal WebSock-compliant WebSocket server for testing Binance stream lenses.
  """
  @behaviour WebSock

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_in({"ping", opcode: :ping}, state) do
    {:reply, :ok, {:pong, "ping"}, state}
  end

  def handle_in({msg, opcode: :text}, state) do
    case Jason.decode!(msg) do
      %{"method" => "SUBSCRIBE", "id" => id} ->
        reply = Jason.encode!(%{"result" => nil, "id" => id})
        {:reply, :ok, {:text, reply}, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_info({:push_stream, frame}, state) do
    {:reply, :ok, {:text, Jason.encode!(frame)}, state}
  end

  def handle_info(:terminate_connection, state) do
    {:stop, :normal, state}
  end
end
```

### 5.3 Core Resiliency Test Scenarios

The test suite must cover 5 critical resilience vector categories:

#### Category A: Connection & Subscription Handshake
Verify that subscribing to a stream (`btcusdt@trade`) sends the subscription JSON frame and emits normalized Lux Signals upon receiving frame payloads.

#### Category B: Reconnection & Backoff Recovery
Simulate unexpected TCP disconnects or server termination (`:terminate_connection`).
Verify that the WebSocket Lens supervisor automatically initiates exponential backoff reconnects without losing state or dropping Lux agent process subscriptions.

#### Category C: Heartbeat Ping / Pong Frames
Binance WebSocket servers issue WebSocket `ping` frames (or JSON `%{"ping" => timestamp}`).
Verify that the client Lens automatically responds with `pong` within the required timeframe to avoid server disconnect.

#### Category D: UserData Stream `listenKey` Keep-Alive
Test that private UserData stream lenses manage the 60-minute `listenKey` lifecycle:
1. Issue POST `/api/v3/userDataStream` on init.
2. Establish WS connection with returned `listenKey`.
3. Schedule periodic PUT `/api/v3/userDataStream` keep-alive requests every 30 minutes.
4. Auto-renew `listenKey` if expired.

#### Category E: Corrupted & Malformed Frame Resilience
Send malformed JSON payloads (`"invalid_json{{"` or missing required fields).
Verify that the Lens logs an error, ignores corrupted data, and remains operational without crashing the GenServer supervisor.

### 5.4 WebSocket Unit & Integration Test Implementation (`test/unit/lux/lenses/binance/ws_lens_test.exs`)

```elixir
defmodule Lux.Lenses.Binance.WebSocketLensTest do
  use UnitCase, async: false
  alias Lux.Test.Support.BinanceFixtures

  setup do
    # Start ephemeral local Bandit server with BinanceWSServer
    {:ok, _pid, port} = start_test_ws_server()
    [ws_url: "ws://127.0.0.1:#{port}/ws"]
  end

  test "connects, subscribes, and processes market trade stream events", %{ws_url: url} do
    {:ok, lens_pid} = Lux.Lenses.Binance.Spot.TradeStreamLens.start_link(url: url, symbol: "BTCUSDT")

    # Verify subscription acknowledgment
    assert_receive {:ws_subscribed, %{"id" => 1, "result" => nil}}, 1000

    # Simulate server broadcasting a trade frame
    send_test_ws_event(lens_pid, %{
      "e" => "trade",
      "E" => 1672515782136,
      "s" => "BTCUSDT",
      "t" => 12345,
      "p" => "65000.00",
      "q" => "0.05"
    })

    # Verify Lux Signal generation
    assert_receive {:signal, %Lux.Signal{payload: %{price: "65000.00", quantity: "0.05"}}}, 1000
  end

  test "reconnects automatically upon server disconnect", %{ws_url: url} do
    {:ok, lens_pid} = Lux.Lenses.Binance.Spot.TradeStreamLens.start_link(url: url, symbol: "BTCUSDT")

    # Force connection drop
    disconnect_test_ws_server(lens_pid)

    # Verify reconnect state transition and re-subscription
    assert_receive {:ws_reconnected, _}, 2000
  end

  test "handles corrupted JSON frame without process termination", %{ws_url: url} do
    {:ok, lens_pid} = Lux.Lenses.Binance.Spot.TradeStreamLens.start_link(url: url, symbol: "BTCUSDT")

    # Push bad payload
    send_raw_ws_frame(lens_pid, "INVALID_RAW_STRING")

    # Verify process is still alive
    assert Process.alive?(lens_pid)
  end

  # Helper functions for local WS lifecycle management
  defp start_test_ws_server do
    # Starts Bandit on ephemeral port with BinanceWSServer handler
    Bandit.Test.start_server(Lux.Test.Support.BinanceWSServer)
  end
end
```

---

## 6. Implementation Checklist & Verification Matrix for Implementers

| Component | Target Test Path | Primary Verification Method |
|---|---|---|
| **Spot HTTP Responses** | `test/unit/lux/lenses/binance/spot_test.exs` | `Req.Test.expect/3` with `BinanceFixtures.spot_order_response/1` |
| **Futures HTTP Responses** | `test/unit/lux/lenses/binance/futures_test.exs` | `Req.Test.expect/3` with `BinanceFixtures.futures_position_risk_response/1` |
| **Rate Limit Retry (429)** | `test/unit/lux/lenses/binance/rate_limit_test.exs` | Sequential `Req.Test.expect/3` simulating `429` -> `200` recovery |
| **HMAC Test Vectors** | `test/unit/lux/lenses/binance/signer_test.exs` | Verify against official Binance API docs spec signature string |
| **WebSocket Lenses** | `test/unit/lux/lenses/binance/ws_lens_test.exs` | Local `Bandit` server double + ping/pong + reconnection assertion |
| **Integration Suite** | `test/integration/lenses/binance_test.exs` | `mix test.integration` using `BINANCE_API_KEY` in `test.override.envrc` |

---

## Conclusion

This strategy provides a robust, zero-flakiness testing foundation for Binance Exchange Integration in Lux. By leveraging `Req.Test` process isolation, step-by-step 429 retry mocking, exact HMAC-SHA256 mathematical test vectors, and local `Bandit` WebSocket doubles, the implementation team can deliver a resilient, high-coverage integration with complete confidence.
