defmodule Lux.Web3.NFTMarketplace do
  @moduledoc """
  NFT Marketplace data aggregation system supporting multiple platforms
  including OpenSea, Blur, and X2Y2.
  """

  alias Lux.Web3.NFTMarketplace.{
    Collection,
    PriceTracker,
    SalesMonitor,
    RarityEngine,
    MarketTrends,
    ListingManager,
    CrossMarketplace
  }

  @type marketplace :: :opensea | :blur | :x2y2
  @type chain :: :ethereum | :polygon | :arbitrum | :optimism

  @doc """
  Returns list of supported marketplaces.
  """
  @spec supported_marketplaces() :: [marketplace()]
  def supported_marketplaces do
    [:opensea, :blur, :x2y2]
  end

  @doc """
  Fetches collection statistics from a specific marketplace.
  """
  @spec get_collection_stats(String.t(), marketplace(), keyword()) ::
          {:ok, Collection.t()} | {:error, term()}
  def get_collection_stats(contract_address, marketplace, opts \\ []) do
    Collection.fetch_stats(contract_address, marketplace, opts)
  end

  @doc """
  Tracks price history for a specific NFT or collection.
  """
  @spec track_price(String.t(), marketplace(), keyword()) ::
          {:ok, PriceTracker.price_data()} | {:error, term()}
  def track_price(asset_identifier, marketplace, opts \\ []) do
    PriceTracker.track(asset_identifier, marketplace, opts)
  end

  @doc """
  Monitors sales activity for a collection or specific NFT.
  """
  @spec monitor_sales(String.t(), marketplace(), keyword()) ::
          {:ok, SalesMonitor.sales_data()} | {:error, term()}
  def monitor_sales(identifier, marketplace, opts \\ []) do
    SalesMonitor.monitor(identifier, marketplace, opts)
  end

  @doc """
  Calculates rarity score for an NFT based on collection traits.
  """
  @spec calculate_rarity(String.t(), String.t(), keyword()) ::
          {:ok, RarityEngine.rarity_score()} | {:error, term()}
  def calculate_rarity(contract_address, token_id, opts \\ []) do
    RarityEngine.calculate(contract_address, token_id, opts)
  end

  @doc """
  Analyzes market trends across collections.
  """
  @spec analyze_market_trends([String.t()], keyword()) ::
          {:ok, MarketTrends.trend_analysis()} | {:error, term()}
  def analyze_market_trends(collection_addresses, opts \\ []) do
    MarketTrends.analyze(collection_addresses, opts)
  end

  @doc """
  Manages listings across marketplaces.
  """
  @spec manage_listings(String.t(), [marketplace()], keyword()) ::
          {:ok, ListingManager.listing_data()} | {:error, term()}
  def manage_listings(asset_identifier, marketplaces, opts \\ []) do
    ListingManager.manage(asset_identifier, marketplaces, opts)
  end

  @doc """
  Compares data across multiple marketplaces for the same asset.
  """
  @spec compare_marketplaces(String.t(), [marketplace()], keyword()) ::
          {:ok, CrossMarketplace.comparison()} | {:error, term()}
  def compare_marketplaces(asset_identifier, marketplaces, opts \\ []) do
    CrossMarketplace.compare(asset_identifier, marketplaces, opts)
  end

  @doc """
  Aggregates comprehensive data for a collection across all supported marketplaces.
  """
  @spec aggregate_collection_data(String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def aggregate_collection_data(contract_address, opts \\ []) do
    marketplaces = Keyword.get(opts, :marketplaces, supported_marketplaces())

    results =
      Enum.map(marketplaces, fn marketplace ->
        Task.async(fn ->
          case Collection.fetch_stats(contract_address, marketplace, opts) do
            {:ok, stats} -> {marketplace, stats}
            {:error, _} -> nil
          end
        end)
      end)
      |> Task.yield_many(30_000)
      |> Enum.map(fn
        {_task, {:ok, result}} when result != nil -> result
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    if map_size(results) > 0 do
      aggregated = %{
        contract_address: contract_address,
        marketplaces: results,
        aggregated_at: DateTime.utc_now(),
        floor_price: aggregate_floor_prices(results),
        total_volume: aggregate_volumes(results),
        holder_count: aggregate_holder_counts(results)
      }

      {:ok, aggregated}
    else
      {:error, :no_data_available}
    end
  end

  # Private helper functions

  defp aggregate_floor_prices(results) do
    results
    |> Enum.map(fn {_marketplace, stats} -> Map.get(stats, :floor_price) end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      prices -> Enum.min(prices)
    end
  end

  defp aggregate_volumes(results) do
    results
    |> Enum.map(fn {_marketplace, stats} -> Map.get(stats, :total_volume, 0) end)
    |> Enum.sum()
  end

  defp aggregate_holder_counts(results) do
    results
    |> Enum.map(fn {_marketplace, stats} -> Map.get(stats, :holder_count) end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      counts -> Enum.max(counts)
    end
  end
end