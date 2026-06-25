 ```diff
--- /dev/null
+++ b/lux/lib/lux/nft_marketplace.ex
@@ -0,0 +1,18 @@
+defmodule Lux.NFTMarketplace do
+  @moduledoc """
+  NFT Marketplace Data Aggregation System for Lux.
+
+  Provides unified access to collection statistics, price tracking,
+  sales monitoring, rarity calculation, trait analysis, market trends,
+  listing management, and cross-marketplace comparison.
+  """
+
+  alias Lux.NFTMarketplace.Aggregator
+  alias Lux.NFTMarketplace.Collection
+  alias Lux.NFTMarketplace.Listing
+  alias Lux.NFTMarketplace.MarketTrends
+  alias Lux.NFTMarketplace.PriceTracker
+  alias Lux.NFTMarketplace.Rarity
+  alias Lux.NFTMarketplace.SalesMonitor
+  alias Lux.NFTMarketplace.TraitAnalysis
+end
--- /dev/null
+++	/lux/lib/lux/nft_marketplace/aggregator.ex
@@ -0,0 +1,148 @@
+defmodule Lux.NFTMarketplace.Aggregator do
+  @moduledoc """
+  Cross-marketplace data aggregation supporting OpenSea, Blur, and X2Y2.
+  """
+
+  alias Lux.NFTMarketplace.Collection
+  alias Lux.NFTMarketplace.Listing
+  alias Lux.NFTMarketplace.PriceTracker
+
+  @type marketplace :: :opensea | :blur | :x2y2
+  @type collection_data :: %{
+          slug: String.t(),
+          name: String.t(),
+          floor_price: float(),
+          total_volume: float(),
+          num_owners: integer(),
+          total_supply: integer(),
+          marketplace: marketplace()
+        }
+
+  @doc """
+  Fetches collection data from all supported marketplaces and aggregates it.
+  """
+  @spec aggregate_collection(String.t()) :: {:ok, map()} | {:error, term()}
+  def aggregate_collection(slug) do
+    marketplaces = [:opensea, :blur, :x2y2]
+
+    results =
+      marketplaces
+      |> Task.async_stream(fn marketplace ->
+        fetch_collection_data(marketplace, slug)
+      end, timeout: 30_000, on_timeout: :kill_task)
+      |> Enum.reduce(%{}, fn
+        {:ok, {:ok, data}}, acc ->
+          Map.put(acc, data.marketplace, data)
+
+        _, acc ->
+          acc
+      end)
+
+    if map_size(results) == 0 do
+      {:error, :no_data_available}
+    else
+      aggregated = %{
+        slug: slug,
+        aggregated: calculate_aggregated_stats(results),
+        marketplaces: results,
+        best_floor: find_best_floor(results),
+        price_discrepancy: calculate_price_discrepancy(results),
+        timestamp: DateTime.utc_now()
+      }
+
+      {:ok, aggregated}
+    end
+  end
+
+  @doc """
+  Compares prices across marketplaces for a given collection.
+  """
+  @spec compare_prices(String.t()) :: {:ok, map()} | {:error, term()}
+  def compare_prices(slug) do
+    case aggregate_collection(slug) do
+      {:ok, data} ->
+        comparison = %{
+          slug: slug,
+          prices: extract_prices(data.marketplaces),
+          savings_opportunities: find_savings(data.marketplaces),
+          recommended_marketplace: recommend_marketplace(data.marketplaces),
+          timestamp: DateTime.utc_now()
+        }
+
+        {:ok, comparison}
+
+      error ->
+        error
+    end
+  end
+
+  # Private functions
+
+  defp fetch_collection_data(:opensea, slug) do
+    Lux.NFTMarketplace.Clients.OpenSea.get_collection(slug)
+  end
+
+  defp fetch_collection_data(:blur, slug) do
+    Lux.NFTMarketplace.Clients.Blur.get_collection(slug)
+  end
+
+  defp fetch_collection_data(:x2y2, slug) do
+    Lux.NFTMarketplace.Clients.X2Y2.get_collection(slug)
+  end
+
+  defp calculate_aggregated_stats(results) do
+    floors = for {_, data} <- results, data.floor_price > 0, do: data.floor_price
+    volumes = for {_, data} <- results, data.total_volume > 0, do: data.total_volume
+
+    %{
+      average_floor: if(length(floors) > 0, do: Enum.sum(floors) / length(floors), else: 0),
+      total_volume_across_marketplaces: Enum.sum(volumes),
+      marketplace_count: map_size(results)
+    }
+  end
+
+  defp find_best_floor(results) do
+    results
+    |> Enum.filter(fn {_, data} -> data.floor_price > 0 end)
+    |> Enum.min_by(fn {_, data} -> data.floor_price end, fn -> nil end)
+  end
+
+  defp calculate_price_discrepancy(results) do
+    floors = for {_, data} <- results, data.floor_price > 0, do: data.floor_price
+
+    if length(floors) > 1 do
+      max = Enum.max(floors)
+      min = Enum.min(floors)
+      (max - min) / minikon
+    else
+      0.0
+    end
+  end
+
+  defp extract_prices(marketplaces) do
+    for {name, data} <- marketplaces, do: %{marketplace: name, floor_price: data.floor_price}
+  end
+
+  defp find_savings(marketplaces) do
+    floors = for {name, data} <- marketplaces, data.floor_price > 0, do: {name, data.floor_price}
+    {cheapest, _} = Enum.min_by(floors, fn {_, price} -> price end)
+    {most_expensive, _} = Enum.max_by(floors, fn {_, price} -> price end)
+
+    if cheapest != most_expensive do
+      [%{buy_at: cheapest, avoid: most_expensive}]
+    else
+      []
+    end
+  end
+
+  defp recommend_marketplace(marketplaces) do
+    floors = for {name, data} <- marketplaces, data.floor_price > 0, do: {name, data.floor_price}
+    {name, _} = Enum.min_by(floors, fn {_, price} -> price end)
+    name
+  end
+end
--- /dev/null
+++