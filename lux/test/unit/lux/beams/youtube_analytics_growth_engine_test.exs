defmodule Lux.Beams.YoutubeAnalyticsGrowthEngineTest do
  use ExUnit.Case, async: true
  doctest Lux.Beams.YoutubeAnalyticsGrowthEngine

  describe "run/1" do
    test "has correct beam metadata" do
      assert Lux.Beams.YoutubeAnalyticsGrowthEngine.__meta__(:name) == "YouTube Analytics Growth Engine"
    end

    test "input schema has required fields" do
      schema = Lux.Beams.YoutubeAnalyticsGrowthEngine.__input_schema__()
      assert "channel_id" in schema[:required]
    end

    test "output schema defines all expected sections" do
      output = Lux.Beams.YoutubeAnalyticsGrowthEngine.__output_schema__()
      assert output[:properties][:channel_metrics] != nil
      assert output[:properties][:growth_predictions] != nil
      assert output[:properties][:revenue_optimization] != nil
      assert output[:properties][:channel_audit] != nil
      assert output[:properties][:benchmarks] != nil
      assert output[:properties][:summary] != nil
    end

    test "returns error for missing channel_id" do
      assert {:error, _} = Lux.Beams.YoutubeAnalyticsGrowthEngine.run(%{})
    end
  end
end
