defmodule Lux.Web3.WalletInfrastructure.TransactionQueue do
  @moduledoc """
  Manages transaction queuing, account nonces, state transitions
  (queued -> signed -> broadcast -> mined -> confirmed),
  and transaction replacement (speed-up and cancellation).
  """

  @type tx_status :: :queued | :signed | :broadcast | :mined | :confirmed | :failed | :dropped

  @type queued_tx :: %{
          id: String.t(),
          from: String.t(),
          to: String.t(),
          chain_id: non_neg_integer(),
          nonce: non_neg_integer(),
          tx_hash: String.t() | nil,
          status: tx_status(),
          max_fee_per_gas: non_neg_integer(),
          max_priority_fee_per_gas: non_neg_integer(),
          created_at: String.t(),
          updated_at: String.t()
        }

  @type queue_state :: %{
          transactions: list(queued_tx()),
          nonces: %{{String.t(), non_neg_integer()} => non_neg_integer()}
        }

  @doc """
  Initializes an empty transaction queue state.
  """
  @spec init_queue() :: queue_state()
  def init_queue do
    %{
      transactions: [],
      nonces: %{}
    }
  end

  @doc """
  Enqueues a new transaction and assigns the next sequential nonce for the account/chain.
  """
  @spec enqueue_transaction(queue_state(), map()) :: {:ok, queue_state(), queued_tx()}
  def enqueue_transaction(queue, params) do
    from = Map.get(params, :from, Map.get(params, "from", "0x0"))
    chain_id = Map.get(params, :chain_id, Map.get(params, "chain_id", 1))

    nonce_key = {String.downcase(from), chain_id}
    current_nonce = Map.get(queue.nonces, nonce_key, 0)

    now = DateTime.utc_now() |> DateTime.to_iso8601()
    tx_id = "tx_queue_#{:os.system_time(:millisecond)}"

    item = %{
      id: tx_id,
      from: from,
      to: Map.get(params, :to, Map.get(params, "to", "0x0")),
      chain_id: chain_id,
      nonce: current_nonce,
      tx_hash: nil,
      status: :queued,
      max_fee_per_gas: Map.get(params, :max_fee_per_gas, 30_000_000_000),
      max_priority_fee_per_gas: Map.get(params, :max_priority_fee_per_gas, 1_500_000_000),
      created_at: now,
      updated_at: now
    }

    updated_queue = %{
      queue
      | transactions: [item | queue.transactions],
        nonces: Map.put(queue.nonces, nonce_key, current_nonce + 1)
    }

    {:ok, updated_queue, item}
  end

  @doc """
  Updates the state of a queued transaction (e.g. from :broadcast to :mined or :confirmed).
  """
  @spec update_tx_status(queue_state(), String.t(), tx_status(), String.t() | nil) ::
          {:ok, queue_state(), queued_tx()} | {:error, :not_found}
  def update_tx_status(queue, tx_id, new_status, tx_hash \\ nil) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Enum.find(queue.transactions, &(&1.id == tx_id)) do
      nil ->
        {:error, :not_found}

      target ->
        updated_target = %{
          target
          | status: new_status,
            tx_hash: tx_hash || target.tx_hash,
            updated_at: now
        }

        updated_list =
          Enum.map(queue.transactions, fn tx ->
            if tx.id == tx_id, do: updated_target, else: tx
          end)

        {:ok, %{queue | transactions: updated_list}, updated_target}
    end
  end

  @doc """
  Builds a cancellation transaction with same nonce and 20% higher gas to front-run and void a pending transaction.
  """
  @spec create_cancellation_tx(queued_tx()) :: map()
  def create_cancellation_tx(%{from: from, chain_id: chain_id, nonce: nonce, max_fee_per_gas: fee, max_priority_fee_per_gas: tip}) do
    %{
      chain_id: chain_id,
      nonce: nonce,
      from: from,
      to: from, # Self transfer with zero value
      value: "0x0",
      data: "0x",
      max_fee_per_gas: round(fee * 1.20),
      max_priority_fee_per_gas: round(tip * 1.20)
    }
  end
end
