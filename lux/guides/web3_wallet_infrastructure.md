# Web3 Wallet Management and Transaction Infrastructure

Lux provides a multi-chain Web3 wallet management and transaction execution infrastructure under `Lux.Web3.Wallet`, `Lux.Web3.Wallet.KeyManager`, `Lux.Web3.Transaction`, `Lux.Web3.Chains`, and `Lux.Prisms.Web3.WalletPrism`.

## Core Capabilities

- **Multi-Wallet Management (`Lux.Web3.Wallet`)**:
  - `:standard` — Single secp256k1 keypair creation and import
  - `:hd` — BIP-32/BIP-44 hierarchical deterministic wallets with indexed child account derivation (`m/44'/60'/0'/0/{index}`)
  - `:hardware` — Hardware wallet signers (Ledger/Trezor callback integration)
  - `:multisig` — M-of-N threshold multi-signature wallets with owner verification
- **Key Security (`Lux.Web3.Wallet.KeyManager`)**:
  - AES-256-GCM authenticated secret encryption with PBKDF2-SHA256 key derivation
  - EIP-55 checksummed address derivation and validation
- **Multi-Chain EVM Registry (`Lux.Web3.Chains`)**:
  - Built-in support for Ethereum, Optimism, BNB Smart Chain, Polygon, Base, Arbitrum One, Avalanche C-Chain, and Sepolia
- **Transaction Lifecycle (`Lux.Web3.Transaction`)**:
  - EIP-1559 and Legacy transaction building, gas & fee estimation, cryptographic signing, nonce-ordered transaction queue execution, and receipt confirmation tracking

## Usage Examples

```elixir
# 1. Create an HD wallet and derive child accounts
{:ok, wallet} = Lux.Web3.Wallet.import_wallet(
  name: "Agent Treasury",
  mnemonic: "test walk nut penalty hip pave soap entry language right filter choice"
)

{:ok, child_account, wallet} = Lux.Web3.Wallet.derive_account(wallet.id, 1)

# 2. Check balances across multiple EVM chains
{:ok, balances} = Lux.Web3.Wallet.get_multi_chain_balances(
  wallet.id,
  [:ethereum, :arbitrum, :polygon]
)

# 3. Build, sign, enqueue, and broadcast an EIP-1559 transaction
{:ok, tx} = Lux.Web3.Transaction.build(wallet, %{
  chain: :arbitrum,
  to: child_account.address,
  value: 100_000_000_000_000_000,
  nonce: 0
})

{:ok, signed_tx} = Lux.Web3.Transaction.sign(tx)
{:ok, _queued} = Lux.Web3.Transaction.enqueue(signed_tx)
{:ok, [broadcasted_tx]} = Lux.Web3.Transaction.process_queue(wallet.id)
```
