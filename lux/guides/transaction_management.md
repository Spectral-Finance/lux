# Gas optimization and transaction management

`Lux.Web3.TransactionManager` provides EIP-1559 fee quotes, simulation, gas
buffers, balance checks, batching and explicit signed transaction submission.
It uses the project's existing Req, ABI and Ethers dependencies.

## Quote and preflight

```elixir
alias Lux.Web3.{Gas, TransactionManager}

opts = [rpc_url: System.fetch_env!("ETH_RPC_URL")]
{:ok, fees} = TransactionManager.quote(opts ++ [speed: :standard, blocks: 2])

# sender and recipient are addresses supplied by your application.
tx = %{"from" => sender, "to" => recipient, "value" => Gas.hex(1_000_000)}
{:ok, plan} = TransactionManager.prepare(tx, opts)
plan.transaction  # unsigned type-2 transaction, with pending nonce and gas limit
plan.simulation   # eth_call return data and eth_estimateGas result
plan.cost         # integer amounts in wei
```

Quotes use 20 blocks of `eth_feeHistory` with tip percentiles `[10, 50, 90]`.
`:slow`, `:standard` and `:fast` select the median of the corresponding column.
The default minimum priority fee is 1 gwei (`:min_priority_fee` overrides it).
The last base-fee entry is the next block's base fee. The maximum fee adds
headroom for `:blocks` additional full blocks (0–25, default 2), following
[EIP-1559](https://eips.ethereum.org/EIPS/eip-1559). All arithmetic uses integers;
no currency conversion or price feed is assumed. Missing or invalid history is
an error, rather than a fabricated price.

Preflight checks the node's chain ID, reads the pending nonce if none was
provided, calls `eth_call` and `eth_estimateGas` at `pending`, and adds a 20%
gas buffer (`:gas_buffer_percent`, 0–100). Explicit fee caps are preserved and
must be supplied together. An explicit gas limit must cover the estimate.
Native balance must cover `value + gas_limit * max_fee_per_gas`.

`expected_fee_wei` uses the gas estimate and `min(max_fee, base_fee + tip)`;
`maximum_fee_wei` uses the gas limit and fee cap. The cap is reserved capacity,
not a claim that it will all be spent. Reverts, invalid transactions, chain
mismatches and insufficient funds return errors before a signer is invoked.

Transactions use JSON-RPC **string** keys. Quantities may be non-negative
integers or hex strings and are normalized before preflight. Only type-2
transactions with `from` and `to` are supported; contract creation, legacy
`gasPrice` and blob transactions are rejected. `accessList` is supported and
validated. RPC options accept `:timeout` (milliseconds, default 15,000) and
`:req_options` for endpoint-specific headers.

## Atomic batching

```elixir
calls = [
  %{"to" => target_a, "data" => calldata_a},
  %{"to" => target_b, "data" => calldata_b}
]

{:ok, comparison} = TransactionManager.plan_batch(
  calls, sender, verified_multicall3_address,
  opts ++ [allow_sender_change: true]
)

comparison.strategy  # :batch or :individual
comparison.gas_saved # estimate; zero when batching is not cheaper
comparison.plans     # prepared plan(s), ready for application review/signing
```

The planner encodes `aggregate3((address,bool,bytes)[])` with every
`allowFailure` set to false, preserves call order, verifies that the batch
address has code, and simulates both paths. It recommends batching only when
its actual node gas estimate is below the sum of individual estimates. The
individual alternative has consecutive nonces and the selected path's total
fee reserve is checked against the sender balance. `TransactionBatch.build/3`
is also available for applications that only need calldata.

Supply an independently verified Multicall3 deployment for your chain. Code
presence alone does not authenticate a contract. Calls must be independent
and zero-value (maximum 100); unknown fields are rejected. Multicall changes
`msg.sender` to its own address at the targets, so explicit
`allow_sender_change: true` is required. Do not batch approvals or operations
whose meaning depends on the original sender. See the
[Multicall3 write semantics](https://github.com/mds1/multicall3#batch-contract-writes).

## Speed up or cancel

```elixir
# pending_tx is the unsigned transaction you originally submitted.
{:ok, fees} = TransactionManager.quote(opts)
{:ok, replacement} = Gas.replace(pending_tx, fees.base_fee_per_gas, :speed_up)
{:ok, replacement_plan} = TransactionManager.prepare(replacement, opts)

# Or cancel the same nonce with a zero-value self transfer:
{:ok, cancellation} = Gas.replace(pending_tx, fees.base_fee_per_gas, :cancel)
{:ok, cancellation_plan} = TransactionManager.prepare(cancellation, opts)
```

Both fee caps are increased by at least 10%, rounded upward with a minimum
increase of one wei. The new maximum fee also covers the supplied base fee
plus the new tip. `:bump_percent` can accommodate a node's stricter policy.
Speed-up preserves transaction intent; cancellation drops the original data,
value, gas limit and access list so the self transfer is estimated afresh.
Only pending transactions can be replaced: check the receipt first, preserve
the chain and nonce, and reconcile racing receipts after sending. Simulation
at `pending` may include the original operation; it cannot guarantee that a
replacement will be accepted or win the race.

## Signing, MEV protection and uncertain submissions

```elixir
# signer.(unsigned_rpc_map) must return {:ok, signed_hex} or {:error, reason}.
# Keep credentials in your application's wallet/HSM, outside this module.
protected_opts = opts ++ [private_rpc_url: System.fetch_env!("ETH_PRIVATE_RPC_URL")]
result = TransactionManager.execute(tx, signer, protected_opts)
```

MEV protection defaults to private-only routing. Set `:private_rpc_url` to a
trusted endpoint supporting `eth_sendRawTransaction`, such as a Protect RPC;
this is not the authenticated `eth_sendPrivateTransaction` relay protocol.
Use `:private_req_options` for that endpoint's headers. Public RPC headers are
never forwarded to it. Private routing reduces public mempool exposure but
still relies on the provider's policy and does not guarantee inclusion.

`execute/3` preflights, invokes the supplied signer, and submits the signed
bytes once. `submit/2` is available for already-signed bytes. Public submission
requires explicit `mev_protection: false`. Neither route follows redirects or
retries requests, and private errors never cause public fallback.

Successful submission returns a hash matching the locally calculated Keccak
hash of the signed bytes. A transport/HTTP failure, malformed response or
unexpected hash returns:

```elixir
{:error, {:submission_unknown, %{transaction_hash: hash, reason: reason}}}
```

Look up that hash and reconcile transaction state before deciding to send
again. A node JSON-RPC rejection is returned as `{:error, {:rpc, error}}`,
including any revert data. Nonce allocation is stateless: applications with
multiple writers must serialize their own pending nonce reservations. A
successful simulation describes a state snapshot, not future execution.

## Gas token compatibility

Historical gas refund tokens are disabled for London-compatible chains due to
[EIP-3529](https://eips.ethereum.org/EIPS/eip-3529). The optional
`Gas.gas_token_savings/2` adapter evaluates a legacy token quote only when the
caller explicitly supplies `%{london: false}`:

```elixir
Gas.gas_token_savings(%{london: false}, fn ->
  {:ok, %{refund_wei: 100, purchase_wei: 10, execution_wei: 20}}
end)
# {:ok, %{use_token: true, net_savings_wei: 70}}
```

These are illustrative wei amounts, not live token quotes. Supply your own
chain-specific quote adapter. The result subtracts purchase and execution
costs and recommends use only for positive savings. It never purchases or
burns tokens, and the adapter is never called for `%{london: true}`.

## Lux agent integration

```elixir
alias Lux.Prisms.Web3.TransactionManagerPrism
TransactionManagerPrism.run(%{action: "quote"}, opts)
TransactionManagerPrism.run(%{action: "prepare", transaction: tx}, opts)
TransactionManagerPrism.run(
  %{action: "batch", calls: calls, from: sender, contract: verified_multicall3_address},
  opts ++ [allow_sender_change: true]
)
```

The prism exposes planning operations; application code explicitly controls
signing and submission.

## Local verification

From `lux/`, with Elixir 1.18, OTP and Foundry's `anvil` on PATH:

```sh
MIX_ENV=test mix deps.get
mix test.unit --no-start test/unit/lux/web3/gas_test.exs test/unit/lux/web3/transaction_manager_test.exs
mix test --no-start --include integration test/integration/web3/transaction_management_test.exs
```

The tests start only Req and a fresh loopback-only Anvil instance, using its
unlocked development accounts. No API keys, external RPC, wallet credentials
or public chain funds are needed. The integration suite deploys the committed
fixtures, compares receipt gas from identical initial state using snapshots,
checks identical final contract state, simulates reverts, replaces real
pending transactions with speed-up/cancel, and signs/submits a local raw
transaction. Private routing and failure paths use Req.Test.

The fixtures are test contracts, not production deployments. Their source is
in `test/fixtures/web3/Transactions.sol`. To regenerate their bytecode, install
`solc@0.8.30` in a separate tooling directory, set `NODE_PATH` to its
`node_modules`, and run `node test/fixtures/web3/compile.cjs`. Compilation uses
the optimizer (200 runs) and the Cancun EVM target. The dedicated gas
transaction workflow runs the same unit and local EVM tests in CI.
