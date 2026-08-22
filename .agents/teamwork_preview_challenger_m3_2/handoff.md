# Handoff Report: Milestone 6 Adversarial Stress Testing (Binance Integration)

**Agent**: Challenger 2 (`teamwork_preview_challenger_m3_2`)  
**Target Project**: Lux Binance Integration (`/home/Konor1743/Operacion Dolar/lux/lux`)  
**Date**: 2026-08-06  

---

## 1. Observation

### 1.1 Compilation and Baseline Test Execution
- Ran `mix compile --warnings-as-errors` in `/home/Konor1743/Operacion Dolar/lux/lux`:
  ```
  The command completed successfully.
  Stdout: (empty - 0 warnings, 0 errors)
  ```
- Ran `mix test test/lux/binance/ test/lux/prisms/binance/`:
  ```
  Finished in 1.1 seconds (0.7s async, 0.4s sync)
  54 tests, 0 failures
  ```

### 1.2 WebSocket & UserDataStream Implementation Inspection
- **`lib/lux/binance/web_socket/client.ex`**:
  ```elixir
  152: def handle_info(_msg, state) do
  153:   {:noreply, state}
  154: end
  ```
  *Observation*: Any disconnection event or process signal (such as `{:disconnect, reason}` or `:tcp_closed`) is matched by `handle_info(_msg, state)` and silently ignored. The client process stays alive with `connected?: true` but does not trigger an automatic reconnection attempt or socket re-establishment.

- **`lib/lux/binance/web_socket/user_data_stream.ex`**:
  ```elixir
  107: def handle_info(:keep_alive, state) do
  108:   opts = [api_key: state.api_key, testnet: state.testnet?, req_options: state.req_options]
  109: 
  110:   case keep_alive_listen_key(state.market_type, state.listen_key, opts) do
  111:     {:ok, _} ->
  112:       Logger.debug("Binance UserDataStream listenKey keep-alive successful: #{state.listen_key}")
  113: 
  114:     {:error, reason} ->
  115:       Logger.warning("Binance UserDataStream listenKey keep-alive failed: #{inspect(reason)}")
  116:   end
  117: 
  118:   timer_ref = schedule_keep_alive()
  119:   {:noreply, %{state | timer_ref: timer_ref}}
  120: end
  ```
  *Observation*: If `keep_alive_listen_key` fails (e.g. HTTP 400 Bad Request with `%{"code" => -1125, "msg" => "This listenKey does not exist."}`), `handle_info(:keep_alive)` logs a warning on line 115, but immediately re-schedules another keep-alive timer on line 118 with the SAME expired/invalid `listen_key`. It does NOT notify the subscriber, does NOT attempt to request a new `listenKey`, and loops indefinitely.

### 1.3 Trading Prisms Schema & Input Handling Inspection
- **`lib/lux/prisms/binance/spot_order_prism.ex`** & **`futures_order_prism.ex`**:
  ```elixir
  54: defp build_order_params(input) do
  55:   input
  56:   |> Map.drop([:api_key, :secret_key, :testnet, :recv_window, :req_options, "api_key", "secret_key", "testnet", "recv_window", "req_options"])
  57:   |> Enum.map(fn {k, v} -> {to_string(k), to_string_val(v)} end)
  58:   |> Map.new()
  59: end
  60: 
  61: defp to_string_val(v) when is_binary(v), do: v
  62: defp to_string_val(v), do: to_string(v)
  ```
  *Observation 1 (`nil` parameter conversion)*: In Elixir, `to_string(nil)` evaluates to `""` (empty string). When `input` contains `symbol: nil` or `quantity: nil`, `to_string_val(nil)` returns `""`, which formats query parameters as `symbol=&quantity=`. When sent to Binance API, Binance returns HTTP 400 Bad Request `code: -1102 ("Mandatory parameter 'symbol' was empty/null, or malformed")`.
  *Observation 2 (Non-primitive map crash)*: When `input` contains complex non-string types such as a map (`quantity: %{complex: 123}`), `to_string(%{complex: 123})` raises `Protocol.UndefinedError: protocol String.Chars not implemented for %{complex: 123}`, crashing the calling process.

### 1.4 Empirical Adversarial Stress Test Suite Creation
Created `test/lux/binance/adversarial_stress_test.exs` containing 27 empirical stress test cases covering WebSockets, UserDataStream, Spot/Futures Trading Prisms, and authentication.

---

## 2. Logic Chain

1. **Premise**: Milestone 6 Binance Integration requires robust WebSocket stream reconnection, `UserDataStream` keep-alive resilience, and strict Spot/Futures Prism input validation.
2. **Analysis of `WebSocket.Client`**:
   - `WebSocket.Client` handles incoming frames via `handle_incoming_frame` and dispatches `Lux.Signal` and event tuples.
   - Unknown messages (such as socket closed or disconnect signals) are ignored by `handle_info(_msg, state)`.
   - Re-sending subscription frames can be triggered via `:send_subscription_frame`, but automatic auto-reconnection upon connection loss is not implemented inside `WebSocket.Client`.
3. **Analysis of `UserDataStream` Renewal Lifecycle**:
   - `UserDataStream.start_link` creates a `listenKey` via POST `/api/v3/userDataStream` or `/fapi/v1/userDataStream` and schedules keep-alive PUT requests every 30 minutes.
   - If the PUT request fails (e.g. expired key, server disconnect, HTTP 400/500), `handle_info(:keep_alive)` logs a warning but reschedules the timer using the same invalid key.
   - The process never attempts to re-create a new `listenKey` or notify subscriber processes of the dead stream state.
4. **Analysis of Trading Prisms Schema & Input Boundaries**:
   - `SpotOrderPrism` and `FuturesOrderPrism` define JSON schemas in `input_schema`, but `Lux.Prism.run/2` delegates directly to `handler/2` without validating input against `input_schema`.
   - Missing mandatory fields (`symbol`, `side`, `type`) pass through `build_order_params` and trigger HTTP 400 error responses from Binance REST API (`code: -1102`).
   - Negative quantities (`quantity: -0.05`), negative prices (`price: -95000.0`), zero quantities (`quantity: 0`), and invalid order types (`side: "INVALID_SIDE"`) pass through `to_string_val` as strings and trigger HTTP 400 error responses (`code: -1100` / `-1013`).
   - `nil` field values are converted by `to_string(nil)` into empty strings `""`, creating query strings like `symbol=&quantity=`.
   - Passing map inputs (`quantity: %{complex: 123}`) causes `to_string/1` to raise `Protocol.UndefinedError`, crashing the execution thread.
5. **Empirical Verification**:
   - Built 27 stress tests in `test/lux/binance/adversarial_stress_test.exs` verifying frame parsing resilience, keep-alive failure logging, missing mandatory fields, boundary values, nil-to-empty string conversion, and map-input crashes. All 27 stress tests pass.

---

## 3. Caveats

- **Network Isolation**: Tests were executed under `CODE_ONLY` network isolation. Live Binance production endpoints (`api.binance.com`, `fapi.binance.com`) were mocked using `Req.Test` plugs matching official Binance REST API status codes, query formats, and JSON payload specs.
- **WebSocket Transport**: Synthetic frames were fed directly via `handle_incoming_frame/2` and GenServer info messages. Full TCP/TLS socket transport reconnection logic was tested at the process message layer.

---

## 4. Conclusion

- **WebSockets & UserDataStream**:
  - WebSocket frame parsing handles valid trade events, corrupted JSON, non-map JSON values, binary/non-UTF8 payloads, and ping/pong frames without crashing.
  - Stream auto-reconnection is supported manually via `:send_subscription_frame`, but `WebSocket.Client` lacks automated socket reconnection triggers when network drop events occur.
  - `UserDataStream` keep-alive PUT failure handling logs warnings but does not attempt self-healing (listenKey re-creation) or subscriber notification upon keepalive expiry.
- **Spot & Futures Trading Prisms**:
  - Prisms handle missing API keys gracefully with `{:error, :missing_secret_key}`.
  - Missing mandatory fields, negative quantities/prices, zero quantities, and invalid enum values are forwarded to Binance REST API, returning proper HTTP 400 error tuples `{:error, %{status: 400, body: %{"code" => ...}}}`.
  - Two input handling vulnerabilities were identified:
    1. `nil` input values convert to empty strings (`"symbol="`), causing API bad request errors instead of client-side validation errors.
    2. Non-primitive map inputs cause `Protocol.UndefinedError` crashes inside `build_order_params`.
- **Suite Verification**:
  - `mix compile --warnings-as-errors` passed cleanly (0 warnings, 0 errors).
  - `mix test test/lux/binance/ test/lux/prisms/binance/` passed 54 total tests with 0 failures.

---

## 5. Verification Method

To independently verify these results, execute the following commands in `/home/Konor1743/Operacion Dolar/lux/lux`:

1. **Verify compilation clean status**:
   ```bash
   mix compile --warnings-as-errors
   ```
2. **Run adversarial stress test suite**:
   ```bash
   mix test test/lux/binance/adversarial_stress_test.exs
   ```
3. **Run all Binance unit & stress tests**:
   ```bash
   mix test test/lux/binance/ test/lux/prisms/binance/
   ```

Files to inspect:
- `test/lux/binance/adversarial_stress_test.exs`
- `lib/lux/binance/web_socket/client.ex`
- `lib/lux/binance/web_socket/user_data_stream.ex`
- `lib/lux/prisms/binance/spot_order_prism.ex`
- `lib/lux/prisms/binance/futures_order_prism.ex`
