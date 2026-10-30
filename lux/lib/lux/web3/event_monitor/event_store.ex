defmodule Lux.Web3.EventMonitor.EventStore do
  @moduledoc """
  ETS-backed persistence for smart contract events.
  Provides deduplication, querying by contract/topic, and historical replay.
  """
  use GenServer

  @table_name :lux_web3_events
  @meta_table :lux_web3_event_meta

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    meta = :ets.new(@meta_table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{events_table: table, meta_table: meta}}
  end

  def save_event(event) do
    id = "#{event[:chain_id] || 1}:#{event[:transaction_hash]}:#{event[:log_index]}"
    case :ets.insert_new(@table_name, {id, Map.put(event, :id, id), System.system_time(:second)}) do
      true -> {:ok, id}
      false -> {:duplicate, id}
    end
  end

  def list_events(opts \\ []) do
    contract = Keyword.get(opts, :contract)
    events = :ets.tab2list(@table_name)
             |> Enum.map(fn {_id, evt, _time} -> evt end)

    if contract do
      contract_down = String.downcase(contract)
      Enum.filter(events, fn e -> String.downcase(e[:address] || "") == contract_down end)
    else
      events
    end
  end

  def replay_events(opts, callback) when is_function(callback, 1) do
    events = list_events(opts)
    Enum.each(events, callback)
    {:ok, length(events)}
  end

  def set_last_synced_block(key, block_number) do
    :ets.insert(@meta_table, {key, block_number})
    :ok
  end

  def get_last_synced_block(key, default \\ 0) do
    case :ets.lookup(@meta_table, key) do
      [{^key, block}] -> block
      [] -> default
    end
  end
end
