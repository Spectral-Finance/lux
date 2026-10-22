defmodule Lux.Lenses.Hyperliquid.FundingHistoryLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.FundingHistoryLens

  @sample_history [
    %{
      "coin" => "BTC",
      "fundingRate" => "0.0000125",
      "premium" => "0.0001",
      "time" => 1_700_000_000_000
    },
    %{
      "coin" => "BTC",
      "fundingRate" => "0.0000130",
      "premium" => "0.00015",
      "time" => 1_700_003_600_000
    }
  ]

  describe "schema and configuration" do
    test "view/0 returns valid lens struct" do
      lens = FundingHistoryLens.view()
      assert lens.name == "Hyperliquid Funding History Lens"
      assert lens.method == :post
      assert lens.schema.required == ["coin", "start_time"]
    end
  end

  describe "before_focus/1" do
    test "constructs fundingHistory query payload" do
      payload = FundingHistoryLens.before_focus(%{coin: "BTC", start_time: 1_700_000_000_000})
      assert payload["type"] == "fundingHistory"
      assert payload["coin"] == "BTC"
      assert payload["startTime"] == 1_700_000_000_000
      refute Map.has_key?(payload, "endTime")
    end

    test "includes endTime when provided" do
      payload =
        FundingHistoryLens.before_focus(%{
          coin: "BTC",
          start_time: 1_700_000_000_000,
          end_time: 1_700_007_200_000
        })

      assert payload["endTime"] == 1_700_007_200_000
    end
  end

  describe "after_focus/1" do
    test "parses list of funding history items" do
      assert {:ok, %{funding_history: history}} = FundingHistoryLens.after_focus(@sample_history)

      assert length(history) == 2
      [first, second] = history

      assert first.coin == "BTC"
      assert first.funding_rate == 0.0000125
      assert first.premium == 0.0001
      assert first.time == 1_700_000_000_000

      assert second.funding_rate == 0.0000130
    end

    test "handles error response" do
      assert {:error, "Invalid coin"} =
               FundingHistoryLens.after_focus(%{"error" => "Invalid coin"})
    end
  end
end
