# Handoff Report — Explorer 1 (Milestone 1)

## 1. Observation

- **Project Root**: `/home/Konor1743/Operacion Dolar/lux/lux`
- **Working Directory**: `/home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_explorer_m1_1`

### Verbatim Observations & Evidence

1. **`mix.exs` Dependencies & Compilation Config** (`/home/Konor1743/Operacion Dolar/lux/lux/mix.exs`):
   - Line 69: `{:req, "~> 0.5.0"}`
   - Line 70: `{:venomous, "~> 0.7.5"}`
   - Line 72: `{:ex_json_schema, "~> 0.10.2"}`
   - Line 82: `{:dotenvy, "~> 1.1.0", only: [:dev, :test]}`
   - Line 83: `{:mock, "~> 0.3.0", only: [:test]}`
   - Line 55-56: Test aliases:
     ```elixir
     "test.unit": "test --include unit",
     "test.integration": "test --include integration",
     ```

2. **Dependency Resolution for WebSockets & JSON** (`/home/Konor1743/Operacion Dolar/lux/lux/mix.lock`):
   - Line 52: `websockex`: `"0.4.3"` (present in `mix.lock` via `ethereumex`, but not top-level in `mix.exs`).
   - `jason`: Present in `mix.lock` via `req` and `ex_json_schema`.

3. **Lens Mechanism** (`/home/Konor1743/Operacion Dolar/lux/lux/lib/lux/lens.ex`):
   - Line 68-115: Macro `__using__` generates struct and registers callbacks `before_focus/1`, `after_focus/1`.
   - Line 141-168: `focus/2` builds HTTP request via `Req.new(...) |> Req.request(...)`.
   - Line 170-191: Auth options (`authenticate/1`) support `:api_key`, `:basic`, `:oauth`, `:custom`.

4. **Prism Mechanism** (`/home/Konor1743/Operacion Dolar/lux/lux/lib/lux/prism.ex`):
   - Line 88: `@callback handler(input :: any(), context :: any()) :: {:ok, any()} | {:error, any()}`
   - Line 90-137: Macro `__using__` configures `:input_schema`, `:output_schema`, `:examples` and generates `run/2` calling `handler/2`.

5. **Existing Integrations Pattern** (`lib/lux/integrations/`):
   - `lib/lux/integrations/discord/client.ex` & `lib/lux/integrations/telegram/client.ex` use `Req.new() |> Req.request()` with plug overrides `maybe_add_plug(opts[:plug])` for test mocking.

6. **Configuration Centralization** (`lib/lux/config.ex` & `config/runtime.exs`):
   - `config/runtime.exs` uses `Dotenvy` to pull environment variables (`env!("...", :string!, required: false)`).
   - `lib/lux/config.ex` exposes central helper functions like `alchemy_api_key/0`, `hyperliquid_account_key/0`, etc.

7. **Test Framework Setup** (`test/test_helper.exs`):
   - Line 1: `ExUnit.start(exclude: [:skip, :integration, :unit])`
   - Line 3-32: `UnitAPICase` sets up `Req.Test` plug routing (`plug: {Req.Test, Lux.Lens}`).

8. **Compilation Result**:
   - `mix compile` executed clean with 0 warnings or errors.

---

## 2. Logic Chain

1. **Observation**: Lux uses `Req` (`~> 0.5.0`) as its core HTTP client and `Req.Test` plug as its official mocking paradigm in `UnitAPICase`.
   - **Reasoning**: A new HTTP integration like Binance MUST follow this pattern by implementing `Lux.Integrations.Binance.Client` using `Req` with plug override support for isolated unit testing without external API calls.

2. **Observation**: Binance integration requires signed requests (HMAC SHA256 using API Secret + Timestamp) for private account endpoints (balances, order creation/cancellation).
   - **Reasoning**: `Lux.Integrations.Binance.Client` should encapsulate the HMAC SHA256 signing logic in Elixir using `:crypto.mac(:hmac, :sha256, secret, query_string)` and inject the `X-MBX-APIKEY` header.

3. **Observation**: Market data queries (ticker, orderbook, klines) are read-only state retrievals, whereas order management actions (create order, cancel order) mutate state.
   - **Reasoning**: Per Lux architectural guidelines, market data endpoints belong in `Lux.Lenses.Binance.*` (implementing `use Lux.Lens`), while order execution belongs in `Lux.Prisms.Binance.*` (implementing `use Lux.Prism`).

4. **Observation**: `websockex` is currently in `mix.lock` (transitive) but not top-level in `mix.exs`.
   - **Reasoning**: For real-time WebSocket market feeds and user data stream events, `{:websockex, "~> 0.4.3"}` should be added as a top-level dependency in `mix.exs`.

5. **Observation**: Configuration parameters are defined in `config/runtime.exs` via `Dotenvy` and accessed in application code via `Lux.Config`.
   - **Reasoning**: Binance credentials (`BINANCE_API_KEY`, `BINANCE_API_SECRET`, `BINANCE_API_URL`, `BINANCE_WS_URL`) should be added to `runtime.exs` and exposed through new getter functions in `Lux.Config`.

---

## 3. Caveats

1. **Unexplored Areas**:
   - Live Binance REST API rate limiting behavior in production environments (e.g. weight limits header `x-mbx-used-weight`).
   - Specific Binance WebSocket reconnect policies under network disconnects (to be detailed in Milestone 2/3).
2. **Environment Variable Dependency**:
   - Running `mix test.unit` across all pre-existing tests requires `.envrc` configuration files for external APIs (e.g., Discord/Telegram API keys). Unit tests written for Binance will mock calls via `Req.Test` and won't require live API keys.
3. **Assumptions**:
   - The initial target exchange endpoints are Binance Spot REST & WebSocket APIs (v3).

---

## 4. Conclusion

The Lux framework provides a highly clean, modular, and extensible architecture. Lenses (`Lux.Lens`) and Prisms (`Lux.Prism`) with `Req` and `Req.Test` are well-suited for building the Binance Exchange Integration in pure Elixir. All architectural analysis findings and detailed implementation proposals have been compiled into `analysis.md`.

---

## 5. Verification Method

To verify this exploration report and analysis:

1. **Inspect Analysis Report**:
   ```bash
   cat /home/Konor1743/Operacion\ Dolar/lux/.agents/teamwork_preview_explorer_m1_1/analysis.md
   ```
2. **Verify Codebase Compilation**:
   ```bash
   cd /home/Konor1743/Operacion\ Dolar/lux/lux
   mix compile --warnings-as-errors
   ```
3. **Inspect Lens and Prism Primitives**:
   - `view_file` on `lib/lux/lens.ex` and `lib/lux/prism.ex`.
