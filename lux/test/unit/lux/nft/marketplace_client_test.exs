defmodule Lux.Nft.MarketplaceClientTest do
  use UnitCase, async: true

  alias Lux.Nft.MarketplaceClient

  describe "URL builders" do
    test "constructs marketplace URLs" do
      assert MarketplaceClient.opensea_collection_url("Bored-Ape-Yacht-Club") ==
               "https://api.opensea.io/api/v2/collections/bored-ape-yacht-club"

      assert MarketplaceClient.opensea_stats_url("cryptopunks") ==
               "https://api.opensea.io/api/v2/collections/cryptopunks/stats"

      assert MarketplaceClient.blur_collection_url("0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d") ==
               "https://api.blur.io/v1/collections/0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
    end
  end

  describe "normalize_stats/2" do
    test "normalizes OpenSea collection stats" do
      data = %{
        "total" => %{
          "floor_price" => "12.5",
          "one_day_volume" => "150.0",
          "total_volume" => "50000.0",
          "total_supply" => 10000,
          "num_owners" => 6400
        }
      }

      stats = MarketplaceClient.normalize_stats(data, :opensea)

      assert stats.floor_price_eth == 12.5
      assert stats.volume_24h_eth == 150.0
      assert stats.total_supply == 10000
      assert stats.num_owners == 6400
      assert stats.marketplace == :opensea
    end

    test "normalizes Blur collection stats" do
      data = %{
        "floorPrice" => "12.45",
        "volumeOneDay" => "220.0",
        "totalVolume" => "48000.0",
        "totalSupply" => "10000",
        "numberOwners" => "6350"
      }

      stats = MarketplaceClient.normalize_stats(data, :blur)

      assert stats.floor_price_eth == 12.45
      assert stats.volume_24h_eth == 220.0
      assert stats.marketplace == :blur
    end
  end
end
