defmodule Lux.Web3.WalletInfrastructure do
  @moduledoc """
  Unified coordinator for Web3 Wallet Management and Multi-Chain Transaction Infrastructure in Lux.

  Provides high-level APIs for:
  - HD wallet generation, derivation, and AES-256-GCM encryption (`generate_mnemonic/1`, `derive_account/2`)
  - Multi-wallet registry management (`register_wallet/5`, `find_wallet/2`)
  - EIP-1559 and EIP-712 transaction construction and signing (`build_tx/1`, `sign_tx/2`)
  - Dynamic gas estimation and speed-up calculation (`estimate_gas/2`, `speed_up_fee/2`)
  - Multi-chain balance tracking across L1 and L2 networks (`fetch_balances/2`)
  - Transaction queue and nonce lifecycle tracking (`init_queue/0`, `enqueue_tx/2`)
  - Historical execution receipt indexing (`query_history/3`)
  - End-to-end automated wallet provisioning (`provision_wallet/2`)
  """

  alias Lux.Web3.WalletInfrastructure.{
    BalanceTracker,
    GasManager,
    HistoryIndexer,
    KeyManager,
    MultiWalletRegistry,
    TransactionBuilder,
    TransactionQueue
  }

  defdelegate generate_mnemonic(words \\ 12), to: KeyManager
  defdelegate derive_account(mnemonic, index \\ 0), to: KeyManager, as: :derive_hd_account
  defdelegate encrypt_key(plain, pass), to: KeyManager
  defdelegate decrypt_key(encrypted, pass), to: KeyManager
  defdelegate valid_private_key?(hex), to: KeyManager

  defdelegate register_wallet(reg, type, addr, label, meta \\ %{}), to: MultiWalletRegistry
  defdelegate find_wallet(reg, addr), to: MultiWalletRegistry, as: :find_by_address

  defdelegate build_tx(params), to: TransactionBuilder, as: :build_eip1559
  defdelegate sign_tx(raw, key), to: TransactionBuilder, as: :sign_transaction
  defdelegate build_eip712(domain, chain_id, contract, types, msg), to: TransactionBuilder, as: :build_eip712_payload

  defdelegate estimate_gas(chain_id, limit \\ 21_000), to: GasManager, as: :estimate_gas_tiers
  defdelegate speed_up_fee(current_max, current_tip), to: GasManager, as: :calculate_speed_up_fee

  defdelegate fetch_balances(address, mock \\ %{}), to: BalanceTracker, as: :fetch_multi_chain_balances

  defdelegate init_queue(), to: TransactionQueue
  defdelegate enqueue_tx(queue, params), to: TransactionQueue, as: :enqueue_transaction
  defdelegate update_tx_status(queue, id, status, hash \\ nil), to: TransactionQueue

  defdelegate record_receipt(history, entry), to: HistoryIndexer
  defdelegate query_history(history, addr, opts \\ []), to: HistoryIndexer

  @doc """
  Provisions a fresh HD wallet, derives primary account, checks multi-chain balances,
  and initializes transaction queue.
  """
  @spec provision_wallet(String.t(), String.t()) :: map()
  def provision_wallet(label \\ "Primary Agent Wallet", passphrase \\ "lux_secure_pass") do
    mnemonic = generate_mnemonic(12)
    account = derive_account(mnemonic, 0)
    encrypted = encrypt_key(mnemonic, passphrase)
    balances = fetch_balances(account.address)
    queue = init_queue()

    {:ok, _reg, record} = register_wallet([], :hd_wallet, account.address, label, %{path: account.path})

    %{
      account: account,
      wallet_record: record,
      encrypted_mnemonic: encrypted,
      balances: balances,
      queue: queue,
      status: :active
    }
  end
end
