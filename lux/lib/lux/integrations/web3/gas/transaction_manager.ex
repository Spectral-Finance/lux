defmodule Lux.Integrations.Web3.Gas.TransactionManager do
  @moduledoc """
  Transaction lifecycle management with speed-up, cancel, and batching.
  """

  use GenServer

  defstruct transactions: %{}, nonce_tracker: %{}

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def submit(pid \\ __MODULE__, tx) do
    GenServer.call(pid, {:submit, tx})
  end

  def speed_up(pid \\ __MODULE__, tx_id, gas_multiplier \\ 1.5) do
    GenServer.call(pid, {:speed_up, tx_id, gas_multiplier})
  end

  def cancel(pid \\ __MODULE__, tx_id) do
    GenServer.call(pid, {:cancel, tx_id})
  end

  def status(pid \\ __MODULE__, tx_id) do
    GenServer.call(pid, {:status, tx_id})
  end

  def list(pid \\ __MODULE__) do
    GenServer.call(pid, :list)
  end

  def batch(pid \\ __MODULE__, transactions) do
    GenServer.call(pid, {:batch, transactions})
  end

  # Server

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call({:submit, tx}, _from, state) do
    id = generate_id()
    entry = %{
      id: id,
      tx: tx,
      status: :pending,
      submitted_at: DateTime.utc_now(),
      gas_price: tx[:gas_price] || tx[:max_fee_per_gas],
      speed_ups: 0,
      hash: nil
    }

    txs = Map.put(state.transactions, id, entry)
    {:reply, {:ok, %{id: id, status: :pending}}, %{state | transactions: txs}}
  end

  @impl true
  def handle_call({:speed_up, tx_id, multiplier}, _from, state) do
    case Map.get(state.transactions, tx_id) do
      nil -> {:reply, {:error, :not_found}, state}
      %{status: :confirmed} -> {:reply, {:error, :already_confirmed}, state}
      entry ->
        new_gas = if entry.gas_price, do: round(entry.gas_price * multiplier), else: nil
        updated = %{entry |
          gas_price: new_gas,
          speed_ups: entry.speed_ups + 1,
          status: :speed_up_pending
        }
        txs = Map.put(state.transactions, tx_id, updated)
        {:reply, {:ok, %{id: tx_id, new_gas_price: new_gas, speed_ups: updated.speed_ups}},
         %{state | transactions: txs}}
    end
  end

  @impl true
  def handle_call({:cancel, tx_id}, _from, state) do
    case Map.get(state.transactions, tx_id) do
      nil -> {:reply, {:error, :not_found}, state}
      %{status: :confirmed} -> {:reply, {:error, :already_confirmed}, state}
      entry ->
        updated = %{entry | status: :cancelled}
        txs = Map.put(state.transactions, tx_id, updated)
        {:reply, {:ok, %{id: tx_id, status: :cancelled}}, %{state | transactions: txs}}
    end
  end

  @impl true
  def handle_call({:status, tx_id}, _from, state) do
    case Map.get(state.transactions, tx_id) do
      nil -> {:reply, {:error, :not_found}, state}
      entry -> {:reply, {:ok, entry}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.transactions), state}
  end

  @impl true
  def handle_call({:batch, transactions}, _from, state) do
    {ids, new_state} = Enum.reduce(transactions, {[], state}, fn tx, {acc_ids, acc_state} ->
      id = generate_id()
      entry = %{
        id: id, tx: tx, status: :batched,
        submitted_at: DateTime.utc_now(),
        gas_price: tx[:gas_price], speed_ups: 0, hash: nil
      }
      txs = Map.put(acc_state.transactions, id, entry)
      {[id | acc_ids], %{acc_state | transactions: txs}}
    end)

    {:reply, {:ok, %{batch_ids: Enum.reverse(ids), count: length(ids)}}, new_state}
  end

  defp generate_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
