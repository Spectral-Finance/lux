defmodule Lux.NFTMarketplace do
  @moduledoc """
  NFT Marketplace Data Aggregation system supporting OpenSea, Blur, and X2Y2.
  
  Provides collection statistics, price tracking, sales monitoring,
  rarity calculation, trait analysis, market trends, and cross-marketplace comparison.
 """
 
 alias Lux.NFTMarketplace.{
   Collection,
   PriceTracker,
   SalesMonitor,
   RarityEngine,
   MarketTrends,
   CrossMarketplace
 }
 
 @type marketplace :: :opensea | :blur | :x2y2
 @type collection_id :: String.t()
 @type token_id :: String.t()
 
 @doc """
 Get collection statistics from a specific marketplace.
 """
 @spec get_collection_stats(marketplace(), collection_id()) :: 
   {:ok, Collection.t()} | {:error, term()}
 def get_collection_stats(marketplace, collection_id) do
   Collection.fetch_stats(marketplace, collection_id)
 end
 
 @doc """
 Get current price data for a specific NFT.
 """
 @spec get_price_data(marketplace(), collection_id(), token_id()) ::
   {:ok, PriceTracker.price_data()} | {:error, term()}
 def get_price_data(marketplace, collection_id, token_id) do
   PriceTracker.get_current_price(marketplace, collection_id, token_id)
 end
 
 @doc """
 Get recent sales for a collection.
 """
 @spec get_recent_sales(marketplace(), collection_id(), keyword()) ::
   {:ok, [SalesMonitor.sale()]} | {:error, term()}
 def get_recent_sales(marketplace, collection_id, opts \\ []) do
   SalesMonitor.get_recent_sales(marketplace, collection_id, opts)
 end
 
 @doc """
 Calculate rarity score for a specific NFT.
 """
 @spec calculate_rarity(collection_id(), token_id()) ::
   {:ok, RarityEngine.rarity_score()} | {:error, term()}
 def calculate_rarity(collection_id, token_id) do
   RarityEngine.calculate(collection_id, token_id)
 end
 
 @doc """
 Get market trends predictions based on historical data.
 """
 @spec get_market_trends(marketplace(), collection_id()) ::
   {:ok, MarketTrends.trend_analysis()} | {:error, term()}
 def get_market_trends(marketplace, collection_id) do
   MarketTrends.analyze(marketplace, collection_id)
 end
 
 @doc """
 Compare prices across multiple marketplaces.
 """
 @spec compare_prices([marketplace()], collection_id(), token_id()) ::
   {:ok, CrossMarketplace.comparison()} | {:error, term()}
 def compare_prices(marketplaces, collection_id, token_id) do
   CrossMarketplace.compare_prices(marketplaces, collection_id, token_id)
 end
 
 @doc """
 Get aggregated data across all supported marketplaces for a collection.
 """
 @spec get_aggregated_data(collection_id()) ::
   {:ok, map()} | {:error, term()}
 def get_aggregated_data(collection_id) do
   CrossMarketplace.get_aggregated_data(collection_id)
 end
end
