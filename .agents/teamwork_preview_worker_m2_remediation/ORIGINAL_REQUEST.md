## 2026-08-06T19:10:00Z

<USER_REQUEST>
You are Worker 2 (Remediation Worker) for Bounty #84 (Binance Exchange Integration in Elixir for Lux framework).

Working directory: /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_worker_m2_remediation
Project root: /home/Konor1743/Operacion Dolar/lux/lux

Read Reviewer 2 handoff report at:
/home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_reviewer_m3_2/handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your Task is to fix ALL 6 findings identified by Reviewer 2:

1. **Fix F-01 (WebSocket Client Genuine Network Transport)**:
   Update `lib/lux/binance/web_socket/client.ex` to use `WebSockex` (`use WebSockex`) for real WebSocket connections to Binance stream base URLs (`wss://stream.binance.com:9443/ws`, `wss://fstream.binance.com/ws`, testnet URLs). Include `WebSockex` callbacks (`handle_connect/2`, `handle_frame/2`, `handle_disconnect/2`) so it is a fully functioning WebSocket client.

2. **Fix F-02 (HMAC Signing & Core Test Failure)**:
   In `lib/lux/binance/auth.ex`, update `sign_params/3`:
   - Sort map parameters deterministically or encode params into a sorted query string where `:signature` (or `"signature"`) is appended strictly as the VERY LAST query parameter.
   - When calling `Req`, ensure `Lux.Binance.Client` appends the signature to the raw URL or query string so `Req` does not re-order query parameters.
   - Fix `test/lux/binance/auth_test.exs` so `mix test` passes 100% without failures.

3. **Fix F-03 (Rate Limiter Backoff Bypass)**:
   In `lib/lux/binance/rate_limiter.ex` (line 129), REMOVE the `actual_sleep < 30_000` condition that bypasses sleep on standard 60-second Binance `Retry-After` penalties!
   Ensure that when rate limited, if `auto_backoff` is enabled, it properly sleeps for the required duration (or returns `{:error, {:rate_limited, wait_ms}}` when auto_backoff is false), preventing requests from hitting Binance during backoff.

4. **Fix F-04 (Auth Defaults on Binary Payload Strings)**:
   In `lib/lux/binance/auth.ex`, when `sign_params/3` receives a binary query string payload without `timestamp` or `recvWindow`, automatically inject `timestamp` and `recvWindow` before signing.

5. **Fix F-05 (UserDataStream Keep-Alive Recovery)**:
   In `lib/lux/binance/web_socket/user_data_stream.ex`, when keep-alive PUT fails (e.g. expired key), attempt to recreate a fresh `listenKey` via POST and restart/reconnect the WebSocket stream rather than infinitely retrying PUT on an invalid key.

6. **Fix F-06 (Order Prism Value Formatting)**:
   In `lib/lux/prisms/binance/spot_order_prism.ex` and `futures_order_prism.ex`, fix `to_string_val`:
   - Return `nil` when input is `nil` (do not format `nil` as `"nil"`).
   - Format floats and numbers properly without raising `UndefinedError` on complex data types.

7. **Verification**:
   Run `mix compile --warnings-as-errors` in /home/Konor1743/Operacion Dolar/lux/lux (MUST pass with 0 warnings, 0 errors).
   Run `mix test` in /home/Konor1743/Operacion Dolar/lux/lux (MUST pass 100% with 0 failures).

Write `changes.md` and `handoff.md` in /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_worker_m2_remediation and notify parent (ID: 2d585f15-4d46-404c-a7a1-200756202c3a).
</USER_REQUEST>
