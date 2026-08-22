# Handoff & Independent Code Review Report — Milestone 6: Binance Exchange Integration

## Review Summary

**Verdict**: **REQUEST_CHANGES**
**Critical Classification**: **INTEGRITY VIOLATION / FACADE IMPLEMENTATION & CORE TEST FAILURE**

- **Project Root**: `/home/Konor1743/Operacion Dolar/lux/lux`
- **Reviewer Directory**: `/home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_reviewer_m3_2`
- **Compilation (`mix compile --warnings-as-errors`)**: Passed (exit code 0)
- **Unit Test Suite (`mix test`)**: FAILED (1 failed test in `Lux.Binance.AuthTest`)

---

## 1. Observation

### Verification Commands & Results
- **Compilation Command**: `mix compile --warnings-as-errors` in `/home/Konor1743/Operacion Dolar/lux/lux`
  - Output: `0 warnings, 0 errors` (Exit status: 0)
- **Test Command**: `mix test` in `/home/Konor1743/Operacion Dolar/lux/lux`
  - Result: Executed 1,398 tests, 1 failure:
    ```
    1) test sign_params/3 correctly signs a parameter map (Lux.Binance.AuthTest)
       test/lux/binance/auth_test.exs:41
       Assertion with == failed
       code:  assert signed[:signature] == "9391a007704a48139902d2827fed43b63027697473090f959dd1eec0b1f26ec8"
       left:  "1d1b4fa4a7857d37947b4bdfcfa496bba91fc90224d7ddaa32631ef02f1bf2db" (seed 752853) / "7996c6f55f180d22a563cbc017daf8ee91f8d962c5293677b61f2dd3f9b9cbc6" (seed 562103)
       right: "9391a007704a48139902d2827fed43b63027697473090f959dd1eec0b1f26ec8"
       stacktrace:
         test/lux/binance/auth_test.exs:55: (test)
    ```

### Direct Code Observations

1. **Facade / Dummy WebSocket Client Implementation** (`lib/lux/binance/web_socket/client.ex`, lines 1-190):
   ```elixir
   defstruct [:url, :market_type, :testnet?, :subscribers, :active_streams, :connected?, :req_options]
   ...
   def init(opts) do
     ...
     state = %__MODULE__{
       url: url,
       market_type: market_type,
       testnet?: testnet?,
       subscribers: MapSet.new([subscriber]),
       active_streams: MapSet.new(streams),
       connected?: true,
       req_options: opts[:req_options] || []
     }
     ...
     {:ok, state}
   end
   ```
   - The module does **NOT** contain any actual WebSocket connection logic (no `WebSockex`, `Gun`, `Mint.WebSocket`, etc.). It sets `:connected?` to `true` statically in memory and relies on unit tests calling `handle_incoming_frame/2` or `send(pid, {:incoming_frame, ...})`.

2. **Nondeterministic Map HMAC Signing & Test Failure** (`lib/lux/binance/auth.ex`, lines 34-44 & `test/lux/binance/auth_test.exs`, lines 41-57):
   ```elixir
   def sign_params(params, secret_key, recv_window) when is_map(params) do
     params_with_defaults = add_auth_defaults_map(params, recv_window)
     query_string = to_query_string(params_with_defaults)
     signature = sign(query_string, secret_key)
     ...
   end
   ```
   - Map key iteration order in Elixir is non-deterministic across Erlang OTP versions and runtime seeds. Passing a map to `URI.encode_query/1` produces varying query string key orders.
   - When passed to `Req.request(req, params: signed_params)`, `Req` re-serializes the map into a query string, potentially placing `:signature` in the middle of the query parameters instead of at the end, causing Binance API HMAC validation failure.

3. **Rate Limiter Standard Backoff Bypassed** (`lib/lux/binance/rate_limiter.ex`, lines 126-135):
   ```elixir
   if auto_backoff and wait_ms > 0 do
     delay_mult = request.options[:retry_delay_multiplier] || 1.0
     actual_sleep = round(wait_ms * delay_mult)
     if actual_sleep > 0 and actual_sleep < 30_000 do
       Process.sleep(actual_sleep)
     end
     request
   else
     request
   end
   ```
   - Standard Binance HTTP 429/418 backoff returns `Retry-After: 60` (60 seconds = 60,000 ms).
   - Because `actual_sleep < 30_000` is evaluated, any backoff wait >= 30,000 ms **skips sleeping entirely** and passes the request through to Binance API, triggering immediate IP bans (HTTP 418).
   - If `auto_backoff` is `false` or backoff wait is active, `pre_request_step` does not return `{:error, :rate_limited}` or abort the HTTP call; it forwards `request` to Binance servers.

4. **Binary Query Payload Missing Auth Defaults** (`lib/lux/binance/auth.ex`, lines 25-32):
   ```elixir
   def sign_params(payload, secret_key, _recv_window) when is_binary(payload) do
     signature = sign(payload, secret_key)
     if payload == "" do
       "signature=" <> signature
     else
       payload <> "&signature=" <> signature
     end
   end
   ```
   - If a binary string payload is passed without `timestamp` or `recvWindow` (e.g. `"symbol=BTCUSDT"`), defaults are not injected, resulting in Binance HTTP 400 rejection (`-1102 Mandatory parameter 'timestamp' was not sent`).

5. **UserDataStream Keep-Alive Recovery Failure** (`lib/lux/binance/web_socket/user_data_stream.ex`, lines 107-120):
   ```elixir
   def handle_info(:keep_alive, state) do
     ...
     case keep_alive_listen_key(state.market_type, state.listen_key, opts) do
       {:ok, _} -> Logger.debug(...)
       {:error, reason} -> Logger.warning(...)
     end

     timer_ref = schedule_keep_alive()
     {:noreply, %{state | timer_ref: timer_ref}}
   end
   ```
   - When keep-alive fails due to temporary network error or key expiration, the GenServer merely logs a warning and indefinitely reschedules keep-alive on the invalid/expired `listenKey` without re-creating a new `listenKey`.

---

## 2. Logic Chain

1. **Integrity Violation via Facade WebSocket Client**:
   - Observation 1 demonstrates that `Lux.Binance.WebSocket.Client` implements a state container GenServer without any actual WebSocket transport layer (no socket initialization, connection handshakes, frames streaming over network, or socket level reconnect logic).
   - Per reviewer guidelines, providing dummy/facade implementations that simulate real logic strictly requires a verdict of `REQUEST_CHANGES` with a Critical finding tagged as **INTEGRITY VIOLATION**.

2. **HMAC Signature Correctness & Test Failure**:
   - Observation 2 shows that `sign_params/3` for map types relies on `URI.encode_query/1` over unordered Elixir maps.
   - The test `test sign_params/3 correctly signs a parameter map` hardcoded an expected hash (`"9391a007..."`) that depended on key ordering under specific Erlang OTP map hashing conditions. On standard runs, this produced different hashes (`"1d1b4fa4..."` / `"7996c6f5..."`), causing unit test failure.
   - In production, Binance requires signature evaluation on the exact string payload and requires `signature` at the end of the query parameter list. Sending a map to `Req` destroys query key order.

3. **Rate Limiter Backoff Flaw**:
   - Observation 3 shows `pre_request_step` in `RateLimiter` checks `actual_sleep < 30_000`.
   - Binance default rate limit backoff is 60 seconds (60,000 ms). When `wait_ms` is 60,000 ms, `actual_sleep < 30_000` is `false`, so `Process.sleep` is bypassed entirely.
   - The middleware forwards the request to Binance while rate-limited, exposing users to HTTP 418 IP bans.

---

## 3. Caveats

- **Network Restrictions**: Operational constraints prevent direct HTTP calls to Binance production or testnet servers; mock testing via `Req.Test` and static analysis were utilized.
- **Dependencies**: No external Elixir WebSocket library (e.g. `WebSockex` or `Mint`) is currently specified in `mix.exs` for Binance WS.

---

## 4. Conclusion

The Binance Exchange Integration requires changes before approval:
1. **INTEGRITY VIOLATION**: Implement real WebSocket transport logic in `Lux.Binance.WebSocket.Client` or clearly document/integrate a proper WebSocket library.
2. **FIX TEST FAILURE & SIGNING**: Update `Lux.Binance.Auth.sign_params/3` to return ordered keyword lists or encoded query strings, ensuring deterministic field ordering and placing `signature` strictly as the final parameter.
3. **FIX RATE LIMITER BACKOFF**: Remove the `< 30_000` ceiling that skips sleeping on 60-second backoffs, or properly return `{:error, {:rate_limited, wait_ms}}` when backoff cannot be waited.
4. **FIX BINARY PAYLOAD AUTH**: Inject `timestamp` and `recvWindow` in `sign_params/3` when passed a binary query string missing those parameters.
5. **FIX USERDATASTREAM RECOVERY**: Re-create `listenKey` on keep-alive failure in `UserDataStream`.

---

## 5. Verification Method

To independently verify these findings:

1. **Compilation Check**:
   ```bash
   cd /home/Konor1743/Operacion\ Dolar/lux/lux
   mix compile --warnings-as-errors
   ```
2. **Unit Test Check (exposes test failure in AuthTest)**:
   ```bash
   cd /home/Konor1743/Operacion\ Dolar/lux/lux
   mix test test/lux/binance/auth_test.exs
   ```
3. **Inspect Code Files**:
   - Check `lib/lux/binance/web_socket/client.ex` for missing WebSocket transport logic.
   - Check `lib/lux/binance/rate_limiter.ex` lines 126-135 for `< 30_000` sleep bypass.
   - Check `lib/lux/binance/auth.ex` lines 25-32 and 34-44 for map key ordering and binary payload defaults.

---

## Findings Matrix

| ID | Severity | Category | File & Location | Description |
|---|---|---|---|---|
| F-01 | **Critical** | **INTEGRITY VIOLATION** | `lib/lux/binance/web_socket/client.ex:1-190` | WebSocket client is a facade GenServer with no real WebSocket connection/socket logic. |
| F-02 | **Critical** | **Correctness / Test Failure** | `lib/lux/binance/auth.ex:34-44` / `test/lux/binance/auth_test.exs:41` | Map signing relies on unordered map key iteration, causing test failure and non-deterministic HMAC signatures. |
| F-03 | **Critical** | **Rate Limiting** | `lib/lux/binance/rate_limiter.ex:129` | Rate Limiter middleware bypasses sleep on backoffs >= 30s (`actual_sleep < 30_000`), failing backoff protection. |
| F-04 | **Major** | **Authentication** | `lib/lux/binance/auth.ex:25-32` | Binary string payload signing does not inject default `timestamp` or `recvWindow` parameters. |
| F-05 | **Major** | **UserDataStream** | `lib/lux/binance/web_socket/user_data_stream.ex:107` | Keep-alive failure does not attempt `listenKey` recreation on expiration/failure. |
| F-06 | **Minor** | **Type Safety** | `lib/lux/prisms/binance/spot_order_prism.ex:61` | `to_string_val(nil)` converts `nil` to `"nil"` string; complex types raise `UndefinedError`. |

---

## Review Dimensions Checklist

- [x] **Correctness**: HMAC signing map issue causing test failure; missing defaults on binary payload.
- [x] **Logical Completeness**: Rate limiter skips backoff >= 30s; UserDataStream keep-alive does not recover key.
- [x] **Quality & Conformance**: Facade implementation detected on WebSocket client.
- [x] **Risk Assessment**: High risk of Binance API rejection (-1102 / 418 bans) in production.
