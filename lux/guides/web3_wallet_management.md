# Web3 Wallet Management & Transaction Infrastructure Guide

This guide details the architecture, design principles, and usage patterns for autonomous agent wallet operations within Lux.

---

## 1. Architecture Overview

Lux provides a complete multi-chain Web3 wallet and transaction management stack designed specifically for autonomous agents requiring secure key custody, automated nonce handling, and multi-network gas optimization.

```mermaid
flowchart TD
    Agent[Autonomous Agent / Prism] --> Facade[Lux.Web3.WalletInfrastructure]
    Facade --> KeyManager[KeyManager\n(BIP-39, BIP-44, AES-256-GCM)]
    Facade --> Registry[MultiWalletRegistry\n(HD, PrivateKey, Multisig)]
    Facade --> TxBuilder[TransactionBuilder\n(EIP-1559 Type 2 & EIP-712)]
    Facade --> GasManager[GasManager\n(Multi-chain Tiers & +15% Speed-up)]
    Facade --> Queue[TransactionQueue\n(Nonce tracking & Lifecycle)]
    Facade --> Balances[BalanceTracker\n(L1/L2 multi-chain balance agg)]
    Facade --> History[HistoryIndexer\n(Receipt log & Gas analytics)]
```

---

## 2. Modules & Capabilities

### 2.1 Key Management (`Lux.Web3.WalletInfrastructure.KeyManager`)
- **BIP-39 Mnemonic Generation**: Generates 12 or 24-word cryptographically secure mnemonics.
- **BIP-44 HD Derivation**: Computes Ethereum-compatible keypairs using `m/44'/60'/0'/0/i`.
- **AES-256-GCM Encryption**: Encrypts sensitive mnemonics and private keys at rest with PBKDF2 salt and authentication tag.

### 2.2 Multi-Wallet Registry (`Lux.Web3.WalletInfrastructure.MultiWalletRegistry`)
- Supports HD wallets, single private keys, multisig vaults (Gnosis Safe style), and hardware wallet proxies.
- Queries wallets by address, tag, or derivation path.

### 2.3 Transaction Builder (`Lux.Web3.WalletInfrastructure.TransactionBuilder`)
- Builds standard EIP-1559 Type-2 transactions (`chain_id`, `max_fee_per_gas`, `max_priority_fee_per_gas`).
- Signs transactions with secp256k1 mock/real signatures.
- Formats EIP-712 typed structured data for permit tokens and governance votes.

### 2.4 Dynamic Gas Manager (`Lux.Web3.WalletInfrastructure.GasManager`)
- Dynamic base fee heuristics for Ethereum Mainnet (1), Arbitrum (42161), Optimism (10), Base (8453), Polygon (137), and BSC (56).
- Gas tiers: `slow`, `standard`, `fast`, `instant`.
- Replacement gas calculation adhering to EVM minimum replacement thresholds (+15% bump).

### 2.5 Transaction Queue & Nonce Tracking (`Lux.Web3.WalletInfrastructure.TransactionQueue`)
- Monotonically increasing account nonces per address and chain.
- State machine: `:queued` -> `:signed` -> `:broadcast` -> `:mined` -> `:confirmed`.
- Generates 0-value self-cancellation transactions with 20% higher priority fees.

### 2.6 Multi-Chain Balance Tracker (`Lux.Web3.WalletInfrastructure.BalanceTracker`)
- Aggregates native token balances (ETH, BNB, POL) across configured chains.
- Calculates total estimated portfolio USD valuation.

### 2.7 History Indexer (`Lux.Web3.WalletInfrastructure.HistoryIndexer`)
- Stores mined transaction receipts.
- Computes cumulative gas expenditures in ETH across arbitrary periods.

---

## 3. Autonomous Agent Prism Integration

Agents invoke the infrastructure seamlessly using `Lux.Prisms.Web3WalletInfrastructurePrism`:

```elixir
# 1. Provision a new agent wallet
{:ok, %{result: wallet}} =
  Lux.Prisms.Web3WalletInfrastructurePrism.run(%{
    action: "provision_wallet",
    payload: %{label: "Treasury Keeper Agent", passphrase: "agent_secret_key"}
  })

# 2. Estimate gas for Base network
{:ok, %{result: gas}} =
  Lux.Prisms.Web3WalletInfrastructurePrism.run(%{
    action: "estimate_gas",
    payload: %{chain_id: 8453, gas_limit: 120_000}
  })

# 3. Enqueue and dispatch transaction
{:ok, %{result: queued_tx}} =
  Lux.Prisms.Web3WalletInfrastructurePrism.run(%{
    action: "enqueue_tx",
    payload: %{
      from: wallet.account.address,
      to: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
      chain_id: 8453,
      max_fee_per_gas: gas.tiers.fast.max_fee_per_gas,
      max_priority_fee_per_gas: gas.tiers.fast.max_priority_fee_per_gas
    }
  })
```
