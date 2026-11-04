defmodule Lux.Beams.Twitter.TwitterAnalyticsPipelineBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Twitter.TwitterAnalyticsPipelineBeam

  describe "TwitterAnalyticsPipelineBeam" do
    test "has expected metadata" do
      assert TwitterAnalyticsPipelineBeam.name() == "TwitterAnalyticsPipelineBeam" ||
             TwitterAnalyticsPipelineBeam.name() == "Twitter Analytics Pipeline Beam"
      assert is_binary(TwitterAnalyticsPipelineBeam.description())
      assert is_map(TwitterAnalyticsPipelineBeam.input_schema())
      assert is_map(TwitterAnalyticsPipelineBeam.output_schema())
    end

    test "beam steps are configured properly" do
      steps = TwitterAnalyticsPipelineBeam.steps()
      assert is_list(steps)
      assert length(steps) >= 4

      step_ids = Enum.map(steps, & &1.id)
      assert :collect_metrics in step_ids
      assert :analyze_sentiment in step_ids
      assert :analyze_hashtags in step_ids
      assert :check_alerts in step_ids
      assert :generate_report in step_ids
    end
  end
end
