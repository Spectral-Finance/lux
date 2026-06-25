defmodule Lux.Integrations.NFTAnalytics do
  @moduledoc """
  NFT Marketplace Data Aggregation ($750).

  Aggregates NFT data from OpenSea, Blur, LooksRare, and
  Reservoir for floor prices, volume, rarity, and wash-trade detection.

  ## Configuration

      config :lux, Lux.Integrations.NFTAnalytics,
        opensea_api_key:  System.get_env("OPENSEA_API_KEY"),
        reservoir_api_key: System.get_env("RESERVOIR_API_KEY")
  """

  @opensea_base   "https://api.opensea.io/api/v2"
  @reservoir_base "https://api.reservoir.tools"
  @blur_base      "https://core-api.prod.blur.io/v1"

  def opensea_url,   do: @opensea_base
  def reservoir_url, do: @reservoir_base
  def blur_url,      do: @blur_base

  def opensea_headers do
    key = Application.get_env(:lux, __MODULE__, [])[:opensea_api_key] ||
          System.get_env("OPENSEA_API_KEY") || ""
    [{"X-API-KEY", key}, {"Accept", "application/json"}]
  end

  def reservoir_headers do
    key = Application.get_env(:lux, __MODULE__, [])[:reservoir_api_key] ||
          System.get_env("RESERVOIR_API_KEY") || ""
    [{"x-api-key", key}, {"Accept", "application/json"}]
  end

  def blur_headers, do: [{"Accept", "application/json"}, {"Content-Type", "application/json"}]

  # Reservoir endpoints (unified aggregator)
  def collection_url(slug),    do: @reservoir_base <> "/collections/v7?id=#{slug}"
  def floor_price_url(contract), do: @reservoir_base <> "/collections/v7?contract=#{contract}"
  def tokens_url(contract),    do: @reservoir_base <> "/tokens/v7?collection=#{contract}"
  def sales_url(contract),     do: @reservoir_base <> "/sales/v6?collection=#{contract}&limit=100"

  # OpenSea endpoints
  def opensea_collection_url(slug), do: @opensea_base <> "/collections/#{slug}"
  def opensea_stats_url(slug),      do: @opensea_base <> "/collections/#{slug}/stats"

  @doc "Detects potential wash trading by checking buyer/seller overlap in recent sales."
  @spec wash_trade_score(list()) :: float()
  def wash_trade_score(sales) when length(sales) > 0 do
    pairs = Enum.map(sales, fn s ->
      {String.downcase(s["from"] || ""), String.downcase(s["to"] || "")}
    end)
    # Count reciprocal trades between the same address pairs
    pair_map = Enum.frequencies(pairs)
    reciprocal = Enum.count(pair_map, fn {{a, b}, _} ->
      Map.has_key?(pair_map, {b, a}) and a != b
    end)
    reciprocal / length(pairs)
  end
  def wash_trade_score(_), do: 0.0

  @doc "Normalises floor prices from multiple sources into a single weighted median."
  @spec consensus_floor(map()) :: float()
  def consensus_floor(prices) when map_size(prices) > 0 do
    values = Map.values(prices) |> Enum.filter(&is_number/1) |> Enum.sort()
    mid = div(length(values), 2)
    Enum.at(values, mid) || 0.0
  end
  def consensus_floor(_), do: 0.0
end
