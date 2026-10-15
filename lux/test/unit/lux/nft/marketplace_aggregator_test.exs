defmodule Lux.Nft.MarketplaceAggregatorTest do
  use ExUnit.Case, async: true
  alias Lux.Nft.MarketplaceAggregator

  test "aggregates cross-marketplace NFT floor asks, top bids, and detects arbitrage" do
    quotes = [
      %{marketplace: :opensea, floor_ask_eth: 12.4, top_bid_eth: 12.1, volume_24h_eth: 140.5},
      %{marketplace: :blur, floor_ask_eth: 12.5, top_bid_eth: 12.6, volume_24h_eth: 410.0}
    ]

    {:ok, res} = MarketplaceAggregator.aggregate_collection("pudgy-penguins", quotes)
    assert res.best_buy_marketplace == :opensea
    assert res.best_sell_marketplace == :blur
    assert res.arbitrage_available == true
    assert res.instant_arb_spread_eth == 0.2
    assert res.total_volume_24h_eth == 550.5
  end
end
