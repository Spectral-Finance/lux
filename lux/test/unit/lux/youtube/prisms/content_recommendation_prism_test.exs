defmodule Lux.YouTube.Prisms.ContentRecommendationPrismTest do
  use ExUnit.Case, async: true

  alias Lux.YouTube.Prisms.ContentRecommendationPrism

  test "ranks recommendations deterministically from channel metrics" do
    input = %{
      "topics" => ["Elixir YouTube automation", "Generic vlog"],
      "audience_segments" => ["Elixir", "automation"],
      "channel_metrics" => %{"average_ctr" => 8.0, "average_retention" => 62.0}
    }

    assert {:ok, %{recommendations: [first, second], model: "deterministic_baseline_v1"}} =
             ContentRecommendationPrism.run(input)

    assert first.topic == "Elixir YouTube automation"
    assert first.score == 0.638
    assert first.confidence == :medium
    assert second.topic == "Generic vlog"
    assert second.score == 0.513
  end
end
