# Web3 Gas Transaction Management

`Lux.Web3.GasTransactionManager` builds deterministic plans for EIP-1559 fee selection, transaction batching, same-nonce replacement, MEV routing, gas reserve strategy, simulation preflight, and cost reporting.

The module intentionally does not sign or broadcast transactions. A wallet or relay adapter should review the returned plan, sign with its own key management, and submit through the selected public RPC or private relay.

## Example

```elixir
{:ok, plan} =
  Lux.Web3.GasTransactionManager.management_plan(%{
    observations: %{
      base_fee_per_gas: "25 gwei",
      priority_fee_per_gas: "1.5 gwei",
      gas_used_ratio: 0.82
    },
    urgency: :fast,
    account_balance_wei: 100_000_000_000_000_000,
    transactions: [
      %{
        from: "0x1111111111111111111111111111111111111111",
        to: "0x3333333333333333333333333333333333333333",
        nonce: 10,
        gas_limit: 120_000,
        value_wei: 0,
        data: "0xabcdef",
        batch_contract: "0x4444444444444444444444444444444444444444"
      }
    ],
    mev: %{risk: :high, relays: ["flashbots"], slippage_bps: 40}
  })
```

Key outputs:

- `gas`: slow, standard, fast, and urgent EIP-1559 fee tiers.
- `batching`: stable nonce-aware execution groups and multicall gas savings when compatible.
- `gas_token_strategy`: native gas reserve and optional account-abstraction paymaster planning.
- `simulations`: deterministic balance, nonce, calldata, and max-fee preflight checks.
- `mev_protection`: private relay, simulation, deadline, slippage, and replacement policy.
- `cost_report`: expected fee, maximum fee, value, and savings versus a baseline.

Use `replacement_transaction/1` to create same-nonce speed-up or cancel payloads when a pending transaction is stuck.
