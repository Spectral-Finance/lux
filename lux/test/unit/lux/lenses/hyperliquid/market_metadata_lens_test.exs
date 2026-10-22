defmodule Lux.Lenses.Hyperliquid.MarketMetadataLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.MarketMetadataLens

  @sample_universe [
    %{
      "name" => "BTC",
      "szDecimals" => 5,
      "maxLeverage" => 50,
      "onlyIsolated" => false
    },
    %{
      "name" => "ETH",
      "szDecimals" => 4,
      "maxLeverage" => 50,
      "onlyIsolated" => false
    }
  ]

  @sample_asset_ctxs [
    %{
      "markPx" => "68000.5",
      "midPx" => "68000.0",
      "oraclePx" => "67990.0",
      "funding" => "0.0000125",
      "openInterest" => "820000000.0",
      "dayNtlVlm" => "1500000000.0",
      "prevDayPx" => "67000.0"
    },
    %{
      "markPx" => "3000.5",
      "midPx" => "3000.0",
      "oraclePx" => "3001.0",
      "funding" => "0.0000100",
      "openInterest" => "460000000.0",
      "dayNtlVlm" => "900000000.0",
      "prevDayPx" => "2950.0"
    }
  ]

  describe "schema and configuration" do
    test "view/0 returns valid lens struct" do
      lens = MarketMetadataLens.view()
      assert lens.name == "Hyperliquid Market Metadata Lens"
      assert lens.method == :post
      assert lens.url == "https://api.hyperliquid.xyz/info"
      assert lens.schema.type == :object
    end
  end

  describe "before_focus/1" do
    test "injects metaAndAssetCtxs type into body" do
      result = MarketMetadataLens.before_focus(%{coin: "BTC"})
      assert result["type"] == "metaAndAssetCtxs"
      assert result["requested_coin"] == "BTC"
    end
  end

  describe "after_focus/1" do
    test "correctly parses and correlates universe and assetCtxs" do
      payload = [%{"universe" => @sample_universe}, @sample_asset_ctxs]
      assert {:ok, %{markets: markets}} = MarketMetadataLens.after_focus(payload)

      assert length(markets) == 2

      btc = Enum.find(markets, &(&1.coin == "BTC"))
      assert btc.max_leverage == 50
      assert btc.mark_price == 68000.5
      assert btc.oracle_price == 67990.0
      assert btc.funding_rate == 0.0000125

      eth = Enum.find(markets, &(&1.coin == "ETH"))
      assert eth.sz_decimals == 4
      assert eth.mark_price == 3000.5
    end

    test "handles error response" do
      assert {:error, "API rate limit"} =
               MarketMetadataLens.after_focus(%{"error" => "API rate limit"})
    end

    test "handles malformed response gracefully" do
      assert {:error, _reason} = MarketMetadataLens.after_focus(%{"invalid" => true})
    end
  end
end
