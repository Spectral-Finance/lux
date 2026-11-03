defmodule Lux.Nft.CrossMarketplaceTest do
  use UnitCase, async: true

  alias Lux.Nft.CrossMarketplace

  describe "compare_listings/2" do
    test "compares listings factoring in fees and royalties" do
      # OpenSea: 10 ETH + 2.5% fee + 5% royalty = 10 * 1.075 = 10.75 ETH
      # Blur: 10.2 ETH + 0.0% fee + 0.5% royalty = 10.2 * 1.005 = 10.251 ETH
      # Blur is cheaper total cost!
      listings = [
        %{marketplace: "opensea", price_eth: 10.0},
        %{marketplace: "blur", price_eth: 10.2}
      ]

      result = CrossMarketplace.compare_listings(listings, 5.0)

      assert result.best_marketplace == :blur
      assert result.lowest_total_cost_eth == 10.251
      assert length(result.listings) == 2
    end
  end
end
