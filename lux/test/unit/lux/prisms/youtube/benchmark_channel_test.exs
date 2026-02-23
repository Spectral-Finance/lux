defmodule Lux.Prisms.YouTube.BenchmarkChannelTest do
  @moduledoc """
  Test suite for the YouTube BenchmarkChannel prism.
  Verifies:
  - Correct percentile and competitive position for leader-tier channel
  - Below-average channel identification
  - Niche-specific benchmarking (tech, gaming, education, lifestyle)
  - Default niche fallback
  - Areas of strength and improvement are properly classified
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.BenchmarkChannel

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "classifies a dominant channel as leader in tech niche" do
      assert {:ok, result} = BenchmarkChannel.handler(
        %{
          "channel_stats" => %{
            "subscriber_count" => 1_500_000,
            "view_count" => 120_000_000,
            "video_count" => 800,
            "avg_views_per_video" => 150_000
          },
          "niche" => "tech"
        },
        @agent_ctx
      )

      assert result.niche == "tech"
      assert result.percentile_rank >= 60
      assert result.competitive_position in ["leader", "above_average"]
      assert "subscriber_count" in result.areas_of_strength
      assert result.areas_for_improvement == []
    end

    test "classifies a new channel as emerging in gaming niche" do
      assert {:ok, result} = BenchmarkChannel.handler(
        %{
          "channel_stats" => %{
            "subscriber_count" => 500,
            "view_count" => 15_000,
            "video_count" => 10,
            "avg_views_per_video" => 1_500
          },
          "niche" => "gaming"
        },
        @agent_ctx
      )

      assert result.niche == "gaming"
      assert result.percentile_rank < 40
      assert result.competitive_position in ["emerging", "below_average"]
      assert length(result.areas_for_improvement) >= 1
    end

    test "benchmarks against education niche correctly" do
      assert {:ok, result} = BenchmarkChannel.handler(
        %{
          "channel_stats" => %{
            "subscriber_count" => 45_000,
            "view_count" => 1_800_000,
            "video_count" => 110,
            "avg_views_per_video" => 16_000
          },
          "niche" => "education"
        },
        @agent_ctx
      )

      assert result.niche == "education"
      assert is_integer(result.percentile_rank)
      assert result.competitive_position in ["leader", "above_average", "average", "below_average", "emerging"]
      assert is_map(result.benchmark_comparison)
      assert Map.has_key?(result.benchmark_comparison, :subscriber_count)
      assert Map.has_key?(result.benchmark_comparison, :avg_views_per_video)
    end

    test "defaults to general niche when niche not specified" do
      assert {:ok, result} = BenchmarkChannel.handler(
        %{
          "channel_stats" => %{
            "subscriber_count" => 50_000,
            "view_count" => 3_000_000,
            "video_count" => 150,
            "avg_views_per_video" => 20_000
          }
        },
        @agent_ctx
      )

      assert result.niche == "general"
      assert is_integer(result.percentile_rank)
    end

    test "percentile rank is always between 0 and 99" do
      for stats <- [
        %{"subscriber_count" => 0, "view_count" => 0, "video_count" => 0, "avg_views_per_video" => 0},
        %{"subscriber_count" => 50_000_000, "view_count" => 10_000_000_000, "video_count" => 10_000, "avg_views_per_video" => 5_000_000}
      ] do
        assert {:ok, result} = BenchmarkChannel.handler(
          %{"channel_stats" => stats, "niche" => "general"},
          @agent_ctx
        )
        assert result.percentile_rank >= 0
        assert result.percentile_rank <= 99
      end
    end
  end
end
