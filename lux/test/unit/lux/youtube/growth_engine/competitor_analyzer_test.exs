defmodule Lux.YouTube.GrowthEngine.CompetitorAnalyzerTest do
  use UnitCase, async: true

  alias Lux.YouTube.GrowthEngine.CompetitorAnalyzer

  describe "benchmark_competitors/3" do
    test "computes market share, competitor profiles, and breakout opportunities" do
      my_views = 40_000
      competitors = [
        %{
          channel_name: "CodeMaster",
          monthly_views: 60_000,
          monthly_uploads: 4,
          subscribers: 50_000,
          breakout_topics: ["Elixir GenServer", "WebAssembly"]
        },
        %{
          channel_name: "SystemDev",
          monthly_views: 100_000,
          monthly_uploads: 8,
          subscribers: 80_000,
          breakout_topics: ["Elixir GenServer", "Distributed Actors"]
        }
      ]

      landscape = CompetitorAnalyzer.benchmark_competitors(my_views, competitors, "elixir")

      assert landscape.niche == "elixir"
      assert landscape.market_share_percentage == 20.0 # 40k / (40k + 160k)
      assert length(landscape.top_competitors) == 2
      assert length(landscape.breakout_opportunities) > 0

      # Most frequent breakout topic should be "Elixir GenServer"
      first_opp = List.first(landscape.breakout_opportunities)
      assert first_opp.topic == "Elixir GenServer"
      assert first_opp.competitor_coverage_count == 2
    end
  end
end
