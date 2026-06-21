defmodule Lux.Web3.TransactionHistory do
  @moduledoc """
  Tracks transaction history for managed wallets. Records each transaction
  sent via the TransactionManager, including status, gas used, and receipts.

  Uses an ETS table for fast in-memory lookups, with the ability to persist
  to external storage if needed.
  """

  use GenServer
  require Logger

  @table :web3_transaction_history

  @type tx_record :: %{
          tx_hash: String.t(),
          from: String.t(),
          to: String.t() | nil,
          value: non_neg_integer(),
          chain_id: pos_integer(),
          status: :pending | :confirmed | :failed | :replaced,
          block_number: non_neg_integer() | nil,
          gas_used: non_neg_integer() | nil,
          nonce: non_neg_integer(),
          submitted_at: DateTime.t(),
          confirmed_at: DateTime.t() | nil,
          metadata: map()
        }

  # --- Public API ---

  @doc """
  Starts the TransactionHistory GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a new pending transaction.
  """
  @spec record_pending(String.t(), map()) :: :ok
  def record_pending(tx_hash, params) do
    record = %{
      tx_hash: tx_hash,
      from: params[:from] || "",
      to: params[:to],
      value: params[:value] || 0,
      chain_id: params[:chain_id] || 1,
      status: :pending,
      block_number: nil,
      gas_used: nil,
      nonce: params[:nonce] || 0,
      submitted_at: DateTime.utc_now(),
      confirmed_at: nil,
      metadata: params[:metadata] || %{}
    }

    :ets.insert(@table, {tx_hash, record})
    :ok
  end

  @doc """
  Updates a transaction record with confirmation data from a receipt.
  """
  @spec record_confirmation(String.t(), map()) :: :ok | {:error, :not_found}
  def record_confirmation(tx_hash, receipt) do
    case :ets.lookup(@table, tx_hash) do
      [{^tx_hash, record}] ->
        status =
          case receipt[:status] do
            1 -> :confirmed
            0 -> :failed
            "0x1" -> :confirmed
            "0x0" -> :failed
            _ -> :confirmed
          end

        updated =
          %{record |
            status: status,
            block_number: receipt[:block_number],
            gas_used: receipt[:gas_used],
            confirmed_at: DateTime.utc_now()
          }

        :ets.insert(@table, {tx_hash, updated})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Marks a transaction as replaced (speed-up or cancel).
  """
  @spec mark_replaced(String.t(), String.t()) :: :ok
  def mark_replaced(old_tx_hash, new_tx_hash) do
    case :ets.lookup(@table, old_tx_hash) do
      [{^old_tx_hash, record}] ->
        updated = %{record | status: :replaced, metadata: Map.put(record.metadata, :replaced_by, new_tx_hash)}
        :ets.insert(@table, {old_tx_hash, updated})
        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Gets a single transaction record by hash.
  """
  @spec get(String.t()) :: {:ok, tx_record()} | {:error, :not_found}
  def get(tx_hash) do
    case :ets.lookup(@table, tx_hash) do
      [{^tx_hash, record}] -> {:ok, record}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns all transaction records for a given sender address, sorted by submission time (newest first).
  """
  @spec list_for_address(String.t(), keyword()) :: [tx_record()]
  def list_for_address(address, opts \\ []) do
    normalized = String.downcase(address)
    limit = Keyword.get(opts, :limit, 100)
    chain_id = Keyword.get(opts, :chain_id)

    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_hash, record} -> record end)
    |> Enum.filter(fn record ->
      String.downcase(record.from) == normalized and
        (chain_id == nil or record.chain_id == chain_id)
    end)
    |> Enum.sort_by(& &1.submitted_at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  @doc """
  Returns the count of transactions for a given address.
  """
  @spec count_for_address(String.t()) :: non_neg_integer()
  def count_for_address(address) do
    normalized = String.downcase(address)

    @table
    |> :ets.tab2list()
    |> Enum.count(fn {_hash, record} -> String.downcase(record.from) == normalized end)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{table: table}}
  end
end
