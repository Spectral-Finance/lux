# Handoff Report: Binance Exchange Integration Testing Strategy (Explorer 3 - Milestone 1)

## 1. Observation

- **Existing Test Architecture**:
  - `lux/test/test_helper.exs`: Configures `ExUnit.start(exclude: [:skip, :integration, :unit])`. Defines `UnitAPICase` module setup registering `Req.Test` plugs (`Application.put_env(:lux, ..., plug: {Req.Test, ...})`). Defines `IntegrationCase` for live external service testing.
  - `lux/guides/testing.md`: Specifies execution via `mix test.unit` and `mix test.integration`, relying on `test.override.envrc` for live credentials.
  - `lux/deps/req/lib/req/test.ex`: Provides process-isolated HTTP mocking via `Req.Test.stub/2` and `Req.Test.expect/3` backed by `Req.Test.Ownership`.
  - `lux/deps/bandit/lib/bandit.ex` & `websockex`: `Bandit` (~> 1.0) and `WebSockEx` are present in dependencies, providing capabilities for running local HTTP/WebSocket test double servers.
- **Binance API Specifications**:
  - Spot REST endpoint: `https://api.binance.com/api/v3/`
  - Futures REST endpoint: `https://fapi.binance.com/fapi/v1/` or `/fapi/v2/`
  - Rate Limiting: `HTTP 429` / `418` returning headers `retry-after` and `x-mbx-used-weight-1m`.
  - HMAC-SHA256 Signatures: `HEX(HMAC-SHA256(secret_key, query_string_or_body))`, requiring `timestamp` and optional `recvWindow`.
  - Official Binance HMAC Vector: Secret `"NhqPtMDL5cvBxT3a65KSTBmUzaw9M6PZ18fLiNFZw9z86St0695BWkTxzYD6dAe3"`, payload `"symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559"`, expected signature `"c822ea44717eee0003010b9cae43486304d9c490a074092b774f26bfa9f12503"`.
  - WebSocket Streams: Spot (`wss://stream.binance.com:9443/ws/`), Futures (`wss://fstream.binance.com/ws/`), and UserData (`listenKey` obtained via POST `/api/v3/userDataStream` refreshed via PUT every 30m).

## 2. Logic Chain

1. **HTTP Mocking (Spot & Futures)**: Because Lux standardizes on `Req` (~> 0.5.0) and `UnitAPICase` registers `Req.Test` plugs, Binance Spot and Futures lenses should plug into `Req.Test`. This ensures zero network access during `mix test.unit` and full support for parallel async tests (`async: true`). Standardized fixture responses should be centralized in `Lux.Test.Support.BinanceFixtures`.
2. **Programmatic 429 Rate Limit Retry Testing**: Binance signals rate limits with HTTP status 429 and `retry-after` header. By chaining sequential `Req.Test.expect/3` calls (e.g. 1st call returns 429, 2nd call returns 200) and configuring lens backoff delays to 1-10 milliseconds in test environment, we can programmatically verify rate limit retry recovery without slowing down CI/test runs.
3. **HMAC-SHA256 Signature Test Vector**: Mathematical verification requires validating the exact HMAC digest calculation against official Binance API documentation specs. By implementing unit tests in `test/unit/lux/lenses/binance/signer_test.exs` using the official payload and secret, we verify canonical parameter serialization, timestamp injection, and hex encoding.
4. **Resilient WebSocket Lens Testing**: Real WebSocket connections cause flaky test suites. By combining local loopback `Bandit` WebSocket double servers (`127.0.0.1:<port>`) with in-memory frame test adapters, we can deterministically test connection initialization, stream subscription handshakes, reconnection backoff, server ping/pong heartbeats, `listenKey` keep-alive loops, and corrupted frame error handling.

## 3. Caveats

- **Network Mode**: Investigation was conducted in `CODE_ONLY` network mode. Remote Binance live endpoints were not directly queried, but official Binance API specifications and Lux dependencies (`mix.exs`, `Req.Test`, `Bandit`) were fully analyzed.
- **WebSocket Library**: Lux includes both `websockex` and `bandit`. The WebSocket lens implementation may use `WebSockEx` or custom `GenServer` for client connections, both of which are fully testable using the specified `Bandit` server double / mock transport pattern.
- **Live Integration Tests**: Live integration tests require valid `BINANCE_API_KEY` and `BINANCE_SECRET_KEY` set in `test.override.envrc` when executing `mix test.integration`.

## 4. Conclusion

A comprehensive, zero-flakiness testing strategy for Binance Exchange Integration (Bounty #84) has been detailed in `/home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_3/analysis.md`. The strategy leverages:
- `Req.Test` plug mocks for Spot and Futures REST endpoints.
- Fast sequential `Req.Test.expect/3` for 429 backoff/retry verification.
- Official Binance HMAC-SHA256 test vectors for cryptographic signing validation.
- Local `Bandit` WebSocket server doubles and test adapters for resilient stream testing.

## 5. Verification Method

To verify the testing strategy recommendations against the existing codebase:
1. Inspect `test/test_helper.exs` to confirm `UnitAPICase` and `Req.Test` plug setup.
2. Inspect `guides/testing.md` to confirm unit/integration test separation conventions.
3. Inspect `test/unit/lux/lens_test.exs` to verify `Req.Test.expect/3` usage patterns.
4. Run existing unit tests via `mix test.unit` from project root `/home/Konor1743/Operacion Dolar/lux/lux` to verify test runner configuration.
