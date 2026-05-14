# Web3 Wallet Infrastructure

`Lux.Web3.WalletInfrastructure` provides offline EVM wallet and transaction primitives for
agents that need to prepare wallet operations before a signer or RPC broadcaster is attached.

The module covers:

- local wallet creation and private-key import with address derivation;
- external, hardware, HD-path, and multi-signature wallet registration;
- EIP-1559 transaction construction with chain metadata and fee bounds;
- local signing through `Ethers.Signer.Local` for test and development flows;
- broadcast request planning without sending network traffic;
- transaction queue state changes and receipt-based monitoring;
- multi-chain balance snapshots.

```elixir
{:ok, wallet} =
  Lux.Web3.WalletInfrastructure.import_wallet(
    "0x1111111111111111111111111111111111111111111111111111111111111111",
    %{chain: :sepolia}
  )

{:ok, tx} =
  Lux.Web3.WalletInfrastructure.build_transaction(%{
    chain: :sepolia,
    from: wallet.address,
    to: "0x2222222222222222222222222222222222222222",
    value_wei: 1_000_000_000_000_000,
    nonce: 7,
    gas: 21_000,
    base_fee_per_gas: 20_000_000_000,
    max_priority_fee_per_gas: 1_500_000_000
  })

{:ok, signed} =
  Lux.Web3.WalletInfrastructure.sign_transaction(tx, %{
    private_key: "0x1111111111111111111111111111111111111111111111111111111111111111"
  })

{:ok, broadcast} = Lux.Web3.WalletInfrastructure.broadcast_plan(signed)
broadcast.broadcast.method
```

Private keys are not returned from created or imported wallet records unless
`include_private_key: true` is explicitly passed. Production applications should prefer
hardware, JSON-RPC, custody, or multi-signature signer references and keep private key material
outside long-lived agent state.
