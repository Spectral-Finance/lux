defmodule Lux.Integrations.MultiChainAggregator.DataStore do
  @moduledoc """
  Efficient data storage and retrieval system for aggregated blockchain data.
  Uses ETS for hot storage and configurable retention policies.
  """

  @default_retention_days 30

  def store_block(chain, block) when is_map(block) do
    table = table_name(chain, :blocks)
    key = {chain, block.number || block[:number]}
    :ets.insert(table, {key, block, System.system_time(:second)})
    :ok
  end

  def store_event(chain, event) when is_map(event) do
    table = table_name(chain, :events)
    key = {chain, event.tx_hash, event.log_index}
    :ets.insert(table, {key, event, System.system_time(:second)})
    :ok
  end

  def get_block(chain, block_number) do
    case :ets.lookup(table_name(chain, :blocks), {chain, block_number}) do
      [{_, block, _}] -> {:ok, block}
      [] -> {:error, :not_found}
    end
  end

  def get_events(chain, opts \\ []) do
    table = table_name(chain, :events)
    address = Keyword.get(opts, :address)
    from_block = Keyword.get(opts, :from_block)
    to_block = Keyword.get(opts, :to_block)

    :ets.tab2list(table)
    |> Enum.filter(fn {_key, event, _ts} ->
      (is_nil(address) or event.address == address) and
      (is_nil(from_block) or (event.block_number || 0) >= from_block) and
      (is_nil(to_block) or (event.block_number || 0) <= to_block)
    end)
    |> Enum.map(fn {_key, event, _ts} -> event end)
  end

  def cleanup_old_data(chain, retention_days \\ @default_retention_days) do
    cutoff = System.system_time(:second) - retention_days * 86_400
    for type <- [:blocks, :events] do
      table = table_name(chain, type)
      :ets.tab2list(table)
      |> Enum.filter(fn {_key, _data, ts} -> ts < cutoff end)
      |> Enum.each(fn {key, _, _} -> :ets.delete(table, key) end)
    end
    :ok
  end

  def init_tables(chain) do
    for type <- [:blocks, :events] do
      table = table_name(chain, type)
      try do
        :ets.new(table, [:named_table, :public, :ordered_set])
      rescue
        ArgumentError -> table
      end
    end
    :ok
  end

  defp table_name(chain, type), do: :"mca_#{chain}_#{type}"
end