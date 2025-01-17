defmodule Lux.Engine.Queue.ETSSignalQueue do
  @moduledoc """
  ETS-based implementation of SignalQueue.
  Uses ordered_set table type to maintain FIFO order using timestamps as keys.
  """

  @behaviour Lux.Engine.Queue.SignalQueue

  @impl true
  def init(opts \\ []) do
    table_name = Keyword.get(opts, :table_name, __MODULE__)

    if table_exists?(table_name) do
      :ets.delete(table_name)
    end

    table =
      :ets.new(table_name, [
        # For FIFO ordering
        :ordered_set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, table}
  end

  @impl true
  def push(table, signal) do
    timestamp = System.monotonic_time(:nanosecond)
    true = :ets.insert(table, {timestamp, signal})
    :ok
  end

  @impl true
  def pop(table) do
    case :ets.first(table) do
      :"$end_of_table" ->
        {:empty, nil}

      key ->
        case :ets.take(table, key) do
          [{_ts, signal}] -> {:ok, signal}
          [] -> {:empty, nil}
        end
    end
  end

  @impl true
  def length(table) do
    :ets.info(table, :size)
  end

  @impl true
  def cleanup(table) do
    if table_exists?(table) do
      :ets.delete(table)
    end

    :ok
  end

  # Private helpers

  defp table_exists?(table) do
    case :ets.info(table) do
      :undefined -> false
      _ -> true
    end
  end
end
