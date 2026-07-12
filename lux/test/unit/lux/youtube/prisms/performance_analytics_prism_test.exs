defmodule Lux.YouTube.Prisms.PerformanceAnalyticsPrismTest do
  use ExUnit.Case, async: true

  alias Lux.YouTube.Prisms.PerformanceAnalyticsPrism

  test "analyzes performance tier and scores videos" do
    input = %{
      "video_data" => [
        %{
          "video_id" => "v1",
          "views" => 15000,
          "watch_time_hours" => 1200,
          "ctr" => 5.2,
          "avg_view_duration" => 6.5
        }
      ]
    }

    assert {:ok, %{analysis_results: [result]}} = PerformanceAnalyticsPrism.run(input)
    assert result.video_id == "v1"
    assert result.performance_score > 50
    assert result.performance_tier == "Excellent"
  end
end
