defmodule Lux.Prisms.Web3.MultiChainAggregatorPrism do
  @moduledoc """
  Lux Prism exposing multi-chain EVM block syncing, smart contract event
  aggregation, historical block indexing, and cross-chain dataset querying.
  """

  use Lux.Prism,
    name: "Multi-Chain Data Aggregation Engine",
    description: "Collects, normalizes, indexes, and queries data across EVM networks",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "sync_latest_blocks, collect_events, query_events, query_blocks, summary"
        },
        chains: %{type: :array, items: %{type: :string}},
        contract_address: %{type: :string},
        event_name: %{type: :string},
        from_block: %{type: :integer},
        to_block: %{type: :integer},
        limit: %{type: :integer}
      },
      required: ["action"]
    }

  alias Lux.Web3.Aggregator

  @impl true
  def handler(params, _ctx) when is_map(params) do
    action = Map.get(params, "action") || Map.get(params, :action)
    dispatch(to_string(action), normalize_keys(params))
  end

  defp dispatch("sync_latest_blocks", params) do
    chains = parse_chains(Map.get(params, :chains, [:ethereum, :polygon, :bsc]))
    Aggregator.sync_latest_blocks(chains)
  end

  defp dispatch("collect_events", params) do
    chains = parse_chains(Map.get(params, :chains, [:ethereum, :polygon]))
    Aggregator.collect_events(chains, params)
  end

  defp dispatch("query_events", params) do
    filters = maybe_convert_chains(params)
    {:ok, Aggregator.query_events(filters)}
  end

  defp dispatch("query_blocks", params) do
    filters = maybe_convert_chains(params)
    {:ok, Aggregator.query_blocks(filters)}
  end

  defp dispatch("summary", _params) do
    {:ok, Aggregator.summary_stats()}
  end

  defp dispatch(other, _params), do: {:error, {:unsupported_action, other}}

  defp maybe_convert_chains(%{chains: chains} = params) when is_list(chains) do
    Map.put(params, :chains, parse_chains(chains))
  end

  defp maybe_convert_chains(params), do: params

  defp parse_chains(chains) do
    Enum.map(chains, fn
      c when is_atom(c) -> c
      "ethereum" -> :ethereum
      "bsc" -> :bsc
      "polygon" -> :polygon
      "arbitrum" -> :arbitrum
      "optimism" -> :optimism
      "base" -> :base
      "avalanche" -> :avalanche
      _ -> :ethereum
    end)
  end

  defp normalize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
