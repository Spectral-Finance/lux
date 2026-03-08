defmodule Lux.Integrations.Web3.WalletManager do
  @moduledoc """
  Multi-wallet management GenServer for tracking wallets, balances, and transactions.

  Supports multiple EVM chains and provides:
  - Wallet creation and import
  - Balance tracking across chains
  - Transaction history
  - Transaction queue management

  ## Usage

      {:ok, pid} = WalletManager.start_link()

      # Create and register a wallet
      {:ok, wallet} = WalletManager.create_wallet(pid, "main")

      # Check balance
      {:ok, balance} = WalletManager.get_balance(pid, "main", :ethereum)

      # List all wallets
      wallets = WalletManager.list_wallets(pid)
  """

  use GenServer
  require Logger

  alias Lux.Integrations.Web3.Wallet

  @supported_chains %{
    ethereum: %{chain_id: 1, rpc: "https://eth.llamarpc.com", symbol: "ETH"},
    polygon: %{chain_id: 137, rpc: "https://polygon-rpc.com", symbol: "MATIC"},
    arbitrum: %{chain_id: 42161, rpc: "https://arb1.arbitrum.io/rpc", symbol: "ETH"},
    optimism: %{chain_id: 10, rpc: "https://mainnet.optimism.io", symbol: "ETH"},
    base: %{chain_id: 8453, rpc: "https://mainnet.base.org", symbol: "ETH"},
    bsc: %{chain_id: 56, rpc: "https://bsc-dataseed.binance.org", symbol: "BNB"},
    avalanche: %{chain_id: 43114, rpc: "https://api.avax.network/ext/bc/C/rpc", symbol: "AVAX"},
    sepolia: %{chain_id: 11155111, rpc: "https://rpc.sepolia.org", symbol: "ETH"}
  }

  defmodule State do
    @moduledoc false
    defstruct wallets: %{}, balances: %{}, tx_history: %{}, tx_queue: []
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc "Create a new wallet and register it with a label."
  def create_wallet(pid, label, opts \\ []) do
    GenServer.call(pid, {:create_wallet, label, opts})
  end

  @doc "Import wallet from private key."
  def import_wallet(pid, label, private_key, opts \\ []) do
    GenServer.call(pid, {:import_wallet, label, private_key, opts})
  end

  @doc "Remove a wallet."
  def remove_wallet(pid, label) do
    GenServer.call(pid, {:remove_wallet, label})
  end

  @doc "List all registered wallets (labels and addresses, no private keys)."
  def list_wallets(pid) do
    GenServer.call(pid, :list_wallets)
  end

  @doc "Get wallet by label."
  def get_wallet(pid, label) do
    GenServer.call(pid, {:get_wallet, label})
  end

  @doc "Get balance for a wallet on a specific chain."
  def get_balance(pid, label, chain \\ :ethereum) do
    GenServer.call(pid, {:get_balance, label, chain}, 15_000)
  end

  @doc "Get balances across all supported chains."
  def get_all_balances(pid, label) do
    GenServer.call(pid, {:get_all_balances, label}, 30_000)
  end

  @doc "Sign a message with a wallet."
  def sign_message(pid, label, message) do
    GenServer.call(pid, {:sign_message, label, message})
  end

  @doc "Queue a transaction for sending."
  def queue_transaction(pid, label, tx_params) do
    GenServer.call(pid, {:queue_transaction, label, tx_params})
  end

  @doc "Get transaction history for a wallet."
  def transaction_history(pid, label) do
    GenServer.call(pid, {:tx_history, label})
  end

  @doc "Get the list of supported chains."
  def supported_chains, do: @supported_chains

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %State{}}
  end

  @impl true
  def handle_call({:create_wallet, label, opts}, _from, state) do
    if Map.has_key?(state.wallets, label) do
      {:reply, {:error, :already_exists}, state}
    else
      case Wallet.create(opts) do
        {:ok, wallet} ->
          state = %{state | wallets: Map.put(state.wallets, label, wallet)}
          {:reply, {:ok, %{label: label, address: wallet.address}}, state}

        error ->
          {:reply, error, state}
      end
    end
  end

  def handle_call({:import_wallet, label, private_key, opts}, _from, state) do
    if Map.has_key?(state.wallets, label) do
      {:reply, {:error, :already_exists}, state}
    else
      case Wallet.from_private_key(private_key, opts) do
        {:ok, wallet} ->
          state = %{state | wallets: Map.put(state.wallets, label, wallet)}
          {:reply, {:ok, %{label: label, address: wallet.address}}, state}

        error ->
          {:reply, error, state}
      end
    end
  end

  def handle_call({:remove_wallet, label}, _from, state) do
    if Map.has_key?(state.wallets, label) do
      state = %{
        state
        | wallets: Map.delete(state.wallets, label),
          balances: Map.delete(state.balances, label),
          tx_history: Map.delete(state.tx_history, label)
      }

      {:reply, :ok, state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:list_wallets, _from, state) do
    wallets =
      Enum.map(state.wallets, fn {label, wallet} ->
        %{label: label, address: wallet.address, chain_id: wallet.chain_id}
      end)

    {:reply, wallets, state}
  end

  def handle_call({:get_wallet, label}, _from, state) do
    case Map.get(state.wallets, label) do
      nil -> {:reply, {:error, :not_found}, state}
      wallet -> {:reply, {:ok, %{address: wallet.address, chain_id: wallet.chain_id}}, state}
    end
  end

  def handle_call({:get_balance, label, chain}, _from, state) do
    with {:ok, wallet} <- fetch_wallet(state, label),
         {:ok, chain_config} <- fetch_chain(chain) do
      case fetch_eth_balance(wallet.address, chain_config.rpc) do
        {:ok, balance} ->
          key = {label, chain}
          balances = Map.put(state.balances, key, %{balance: balance, updated_at: DateTime.utc_now()})
          state = %{state | balances: balances}

          {:reply, {:ok, %{balance: balance, chain: chain, symbol: chain_config.symbol}}, state}

        error ->
          {:reply, error, state}
      end
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:get_all_balances, label}, _from, state) do
    case fetch_wallet(state, label) do
      {:ok, wallet} ->
        results =
          Enum.map(@supported_chains, fn {chain, config} ->
            balance =
              case fetch_eth_balance(wallet.address, config.rpc) do
                {:ok, bal} -> bal
                _ -> nil
              end

            {chain, %{balance: balance, symbol: config.symbol}}
          end)
          |> Map.new()

        {:reply, {:ok, results}, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:sign_message, label, message}, _from, state) do
    case fetch_wallet(state, label) do
      {:ok, wallet} ->
        {:reply, Wallet.sign_message(wallet, message), state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:queue_transaction, label, tx_params}, _from, state) do
    case fetch_wallet(state, label) do
      {:ok, _wallet} ->
        tx_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

        entry = %{
          id: tx_id,
          label: label,
          params: tx_params,
          status: :queued,
          queued_at: DateTime.utc_now()
        }

        state = %{state | tx_queue: state.tx_queue ++ [entry]}
        {:reply, {:ok, tx_id}, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:tx_history, label}, _from, state) do
    history = Map.get(state.tx_history, label, [])
    {:reply, {:ok, history}, state}
  end

  # Private helpers

  defp fetch_wallet(state, label) do
    case Map.get(state.wallets, label) do
      nil -> {:error, :not_found}
      wallet -> {:ok, wallet}
    end
  end

  defp fetch_chain(chain) do
    case Map.get(@supported_chains, chain) do
      nil -> {:error, {:unsupported_chain, chain}}
      config -> {:ok, config}
    end
  end

  defp fetch_eth_balance(address, rpc_url) do
    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 1,
        method: "eth_getBalance",
        params: [address, "latest"]
      })

    case Req.post(rpc_url, body: body, headers: [{"content-type", "application/json"}], receive_timeout: 10_000) do
      {:ok, %{status: 200, body: %{"result" => hex_balance}}} ->
        wei = hex_to_integer(hex_balance)
        eth = wei / 1.0e18
        {:ok, %{wei: wei, eth: Float.round(eth, 8)}}

      {:ok, %{body: %{"error" => error}}} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hex_to_integer("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_integer("0x"), do: 0
  defp hex_to_integer(hex), do: String.to_integer(hex, 16)
end
