defmodule Lux.Integrations.MultiChainAggregator.QueryEngine do
  @moduledoc """
  Query interface for aggregated multi-chain data.
  Supports filtering, aggregation, and cross-chain queries.
  """

  alias Lux.Integrations.MultiChainAggregator.DataStore

  @type query :: map()

  @doc "Execute a query against aggregated data"
  def execute(%{chains: chains, type: :events} = query) do
    chains
    |> Enum.map(fn chain ->
      events = DataStore.get_events(chain,
        address: query[:address],
        from_block: query[:from_block],
        to_block: query[:to_block]
      )
      {chain, events}
    end)
    |> Enum.into(%{})
  end

  def execute(%{chains: chains, type: :blocks} = query) do
    chains
    |> Enum.map(fn chain ->
      blocks = for b <- (query[:from_block]..(query[:to_block] || query[:from_block])) do
        case DataStore.get_block(chain, b) do
          {:ok, block} -> block
          {:error, _} -> nil
        end
      end
      |> Enum.reject(&is_nil/1)
      {chain, blocks}
    end)
    |> Enum.into(%{})
  end

  def execute(%{chains: chains, type: :stats} = _query) do
    chains
    |> Enum.map(fn chain ->
      block_count = :ets.info(table_name(chain, :blocks), :size)
      event_count = :ets.info(table_name(chain, :events), :size)
      {chain, %{blocks: block_count, events: event_count}}
    end)
    |> Enum.into(%{})
  end

  defp table_name(chain, type), do: :"mca_#{chain}_#{type}"
end