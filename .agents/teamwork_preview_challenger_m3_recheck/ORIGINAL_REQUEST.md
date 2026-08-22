## 2026-08-06T19:34:38Z
You are Challenger 3 for Milestone 6 of Bounty #84 (Binance Exchange Integration in Elixir for Lux framework).

Working directory: /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_challenger_m3_recheck
Project root: /home/Konor1743/Operacion Dolar/lux/lux

Your Task:
1. Conduct empirical adversarial stress testing on the remediated Binance codebase:
   - Test WebSockex integration in `Lux.Binance.WebSocket.Client`.
   - Test deterministic HMAC parameter sorting and `:signature` positioning in `Lux.Binance.Auth`.
   - Test 60s backoff sleeping/halting in `Lux.Binance.RateLimiter`.
   - Test binary payload auth defaults in `Lux.Binance.Auth.sign_params/3`.
   - Test UserDataStream listenKey renewal on keep-alive error.
   - Test Prism input parameter handling for Spot and Futures orders.
2. Run `mix compile --warnings-as-errors` and `mix test` in /home/Konor1743/Operacion Dolar/lux/lux.
3. Write handoff.md in /home/Konor1743/Operacion Dolar/lux/.agents/teamwork_preview_challenger_m3_recheck and notify parent (ID: 2d585f15-4d46-404c-a7a1-200756202c3a).
