# Execution Plan: Binance Exchange Integration (Bounty #84 - $750 USD)

## Architecture Overview
The integration provides a native Elixir adapter for Binance Spot and USDⓈ-M Futures within the Lux framework (`Lux.Integrations.Binance` or `Lux.Binance`).

### Key Modules & Components
1. **Authentication & REST Clients** (`Lux.Binance.Auth`, `Lux.Binance.Client`, `Lux.Binance.Spot.Client`, `Lux.Binance.Futures.Client`)
   - HMAC-SHA256 signature calculation over request query string & payload.
   - Support for both Spot REST API (`https://api.binance.com`) and Futures REST API (`https://fapi.binance.com`).
   - Public and private endpoints handling.

2. **Rate Limiting Engine & Middleware** (`Lux.Binance.RateLimiter`)
   - Weight tracking & Raw request counter.
   - Intercept 429 status codes and handle `Retry-After` header.
   - Exponential backoff and request queueing/throttling.

3. **WebSockets & Market Data Lenses** (`Lux.Binance.WebSocketClient`, `Lux.Binance.Lenses.*`)
   - `Lux.Binance.Lenses.BinanceTickerPriceLens`: Real-time ticker price streaming.
   - `Lux.Binance.Lenses.BinanceExchangeInfoLens`: Exchange information lens.
   - Resilient connection management with automatic reconnection on disconnect.

4. **Trading Systems (Prisms)** (`Lux.Binance.Prisms.Spot.*`, `Lux.Binance.Prisms.Futures.*`)
   - **Spot Prisms**:
     * `Lux.Binance.Prisms.Spot.AccountPrism` (`BinanceSpotAccountPrism`)
     * `Lux.Binance.Prisms.Spot.OrderPrism` (`BinanceSpotOrderPrism`)
     * `Lux.Binance.Prisms.Spot.CancelOrderPrism` (`BinanceSpotCancelOrderPrism`)
     * `Lux.Binance.Prisms.Spot.OpenOrdersPrism` (`BinanceSpotOpenOrdersPrism`)
   - **Futures Prisms**:
     * `Lux.Binance.Prisms.Futures.AccountPrism` (`BinanceFuturesAccountPrism`)
     * `Lux.Binance.Prisms.Futures.OrderPrism` (`BinanceFuturesOrderPrism`)
     * `Lux.Binance.Prisms.Futures.PositionPrism` (`BinanceFuturesPositionPrism`)
     * `Lux.Binance.Prisms.Futures.CancelOrderPrism` (`BinanceFuturesCancelOrderPrism`)

5. **ExUnit Test Suite & Documentation**
   - Mock HTTP adapters (`Req.Test` or custom plug/mock) for Spot & Futures REST API.
   - Unit test for HMAC-SHA256 signature verification matching Binance API specifications.
   - Programmatic test verifying 429 rate limit backoff and retry behavior.
   - Full `@moduledoc` and `@doc` coverage with usage examples.

---

## Milestones

| # | Milestone Name | Scope | Key Deliverables | Status |
|---|----------------|-------|------------------|--------|
| M1 | Investigation & Codebase Analysis | Analyze Lux framework structure, Lens/Prism patterns, Req HTTP integration, WebSocket utilities | Handoff analysis, design spec | IN_PROGRESS |
| M2 | REST Clients, Auth & Rate Limiter | HMAC-SHA256 Auth module, Spot & Futures REST clients, 429 Rate Limiter middleware | `Lux.Binance.Auth`, `Lux.Binance.Client`, `Lux.Binance.RateLimiter` | PLANNED |
| M3 | Market Data WebSockets & Lenses | Resilient WebSocket stream manager, `BinanceTickerPriceLens`, `BinanceExchangeInfoLens` | `Lux.Binance.WebSocketClient`, `Lux.Binance.Lenses.*` | PLANNED |
| M4 | Trading Systems (Spot & Futures Prisms) | 4 Spot Prisms (`Account`, `Order`, `CancelOrder`, `OpenOrders`), 4 Futures Prisms (`Account`, `Order`, `Position`, `CancelOrder`) | `Lux.Binance.Prisms.Spot.*`, `Lux.Binance.Prisms.Futures.*` | PLANNED |
| M5 | Test Suite, Docs & Hardening | Complete ExUnit tests with HTTP mocks, HMAC verification test, 429 retry test, full `@moduledoc`/`@doc` | `test/lux/binance/*`, documentation | PLANNED |
| M6 | Forensic Integrity Audit & Victory Signal | Verification by Forensic Auditor, zero compilation warnings, victory signal to Sentinel | Audit report, victory signal | PLANNED |

---

## Acceptance Criteria Checklist
- [ ] 100% compilation without warnings (`mix compile --warnings-as-errors`).
- [ ] `@moduledoc` and `@doc` documentation with Elixir examples for every Prism and Lens.
- [ ] All `mix test` pass cleanly.
- [ ] Programmatic test verifying 429 rate limit backoff and retry.
- [ ] Mathematical unit test verifying HMAC-SHA256 signature against Binance spec.
- [ ] Forensic Auditor verdict is CLEAN (no integrity violations or shortcuts).
