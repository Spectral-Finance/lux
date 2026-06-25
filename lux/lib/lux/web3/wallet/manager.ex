defmodule Lux.Web3.Wallet.Manager do
  @moduledoc """
  Web3 Wallet Management System for Lux ($2,000 bounty #73).
  Hot wallets, multi-sig, tx signing, address book, DApp connections, backup/restore.
  """
  use GenServer
  alias Lux.Web3.Wallet.{Store, MultiSig, Backup}

  @spec start_link(list()) :: GenServer.on_start()
  def start_link(opts \ \[]), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec create_wallet(String.t() | nil, [atom()]) :: {:ok, map()} | {:error, term()}
  def create_wallet(label \ nil, chains \ [:ethereum]), do: GenServer.call(__MODULE__, {:create_wallet, label, chains})

  @spec sign_transaction(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def sign_transaction(addr, tx), do: GenServer.call(__MODULE__, {:sign, addr, tx})

  @spec create_multisig([String.t()], non_neg_integer(), String.t() | nil) :: {:ok, map()} | {:error, term()}
  def create_multisig(signers, threshold, label \ nil) when length(signers) >= threshold and threshold >= 2 do
    GenServer.call(__MODULE__, {:create_multisig, signers, threshold, label})
  end

  @spec backup_wallet(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def backup_wallet(addr, fmt), do: GenServer.call(__MODULE__, {:backup, addr, fmt})

  @impl true
  def init(_), do: {:ok, %{wallets: %{}, multisigs: %{}, address_books: %{}, dapps: %{}}}

  @impl true
  def handle_call({:create_wallet, label, chains}, _from, state) do
    case Store.generate_wallet() do
      {:ok, w} ->
        e = %{address: w.address, label: label || String.slice(w.address, 0, 8), type: :hot,
          chains: chains, created_at: DateTime.utc_now() |> DateTime.to_iso8601()}
        {:reply, {:ok, e}, Map.update!(state, :wallets, &Map.put(&1, w.address, e))}
      {:error, r} -> {:reply, {:error, r}, state}
    end
  end

  @impl true
  def handle_call({:sign, addr, tx}, _from, state) do
    case state.wallets[addr] do
      nil -> {:reply, {:error, "Wallet not found"}, state}
      _ -> Store.sign_transaction(addr, tx)
    end
  end

  @impl true
  def handle_call({:create_multisig, signers, threshold, label}, _from, state) do
    id = MultiSig.generate_id()
    entry = %{id: id, label: label || id, signers: signers, threshold: threshold,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(), pending_txs: %{}, executed_txs: []}
    {:reply, {:ok, entry}, Map.update!(state, :multisigs, &Map.put(&1, id, entry))}
  end

  @impl true
  def handle_call({:backup, addr, fmt}, _from, state) do
    case state.wallets[addr] do
      nil -> {:reply, {:error, "Wallet not found"}, state}
      _ -> Backup.export_wallet(addr, fmt)
    end
  end

  @impl true
  def handle_call(:list_wallets, _from, state), do: {:reply, Map.values(state.wallets), state}
end