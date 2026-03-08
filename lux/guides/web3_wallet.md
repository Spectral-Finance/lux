# Web3 Wallet Management

Multi-chain wallet management and transaction infrastructure for Lux agents.

## Quick Start

```elixir
# Create a wallet
alias Lux.Integrations.Web3.Wallet

{:ok, wallet} = Wallet.create()
IO.puts("Address: #{wallet.address}")

# Sign a message
{:ok, signature} = Wallet.sign_message(wallet, "Hello, Web3!")

# Verify signature
true = Wallet.verify_signature("Hello, Web3!", signature, wallet.address)
```

## Wallet Manager

The `WalletManager` GenServer manages multiple wallets with labels:

```elixir
alias Lux.Integrations.Web3.WalletManager

{:ok, pid} = WalletManager.start_link()

# Create wallets
{:ok, %{address: addr}} = WalletManager.create_wallet(pid, "trading")
{:ok, _} = WalletManager.create_wallet(pid, "savings")

# Check balance on Ethereum
{:ok, %{balance: bal}} = WalletManager.get_balance(pid, "trading", :ethereum)

# Check all chains
{:ok, balances} = WalletManager.get_all_balances(pid, "trading")

# Sign messages
{:ok, sig} = WalletManager.sign_message(pid, "trading", "Authorize trade #123")
```

## Supported Chains

| Chain | Symbol | Chain ID |
|-------|--------|----------|
| Ethereum | ETH | 1 |
| Polygon | MATIC | 137 |
| Arbitrum | ETH | 42161 |
| Optimism | ETH | 10 |
| Base | ETH | 8453 |
| BSC | BNB | 56 |
| Avalanche | AVAX | 43114 |
| Sepolia (testnet) | ETH | 11155111 |

## Transaction Signing

Build and sign EIP-1559 transactions:

```elixir
alias Lux.Integrations.Web3.Wallet

{:ok, wallet} = Wallet.create(chain_id: 1)

tx = Wallet.build_transaction(%{
  to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73",
  value: 1_000_000_000_000_000_000,  # 1 ETH in wei
  nonce: 0,
  gas_limit: 21_000,
  max_fee_per_gas: 30_000_000_000,
  max_priority_fee_per_gas: 1_500_000_000
})

{:ok, signed_tx} = Wallet.sign_transaction(wallet, tx)
```

## Prisms

### CreateWallet

```elixir
# Via Prism
{:ok, result} = Lux.Prisms.Web3.CreateWallet.handler(%{action: "create", chain_id: 1}, [])
# => %{address: "0x...", chain_id: 1, private_key: "0x..."}
```

### SignTransaction

```elixir
{:ok, result} = Lux.Prisms.Web3.SignTransaction.handler(%{
  private_key: "0xabc...",
  to: "0x742d35Cc...",
  value: 1_000_000_000_000_000_000
}, [])
# => %{signed_tx: "0x02f8...", from: "0x...", to: "0x...", value: ...}
```

## Lenses

### GetBalance

```elixir
{:ok, result} = Lux.Lenses.Web3.GetBalance.focus(%{
  address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
  chain: "ethereum"
})
# => %{balance: 1.5, balance_wei: 1500000000000000000, symbol: "ETH"}
```

### GetTransactionStatus

```elixir
{:ok, result} = Lux.Lenses.Web3.GetTransactionStatus.focus(%{
  tx_hash: "0x123...",
  chain: "ethereum"
})
# => %{status: :confirmed, block_number: 19000000, gas_used: 21000}
```

## Security Notes

- Private keys are stored in-memory only (not persisted to disk)
- Use the WalletManager for production; direct Wallet creation for one-off operations
- Always validate addresses before sending transactions
- Test on Sepolia before mainnet operations
