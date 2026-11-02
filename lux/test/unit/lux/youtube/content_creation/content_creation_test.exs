defmodule Lux.YouTube.ContentCreationTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentCreation

  describe "build_pipeline/1" do
    test "executes full pipeline producing script, editing, visual specs, repurposed assets, and A/B test" do
      pipeline = ContentCreation.build_pipeline(%{
        topic: "Building Resilient AI Agents with Lux",
        format: :tutorial,
        target_minutes: 10.0
      })

      assert pipeline.status == :production_ready
      assert pipeline.topic == "Building Resilient AI Agents with Lux"
      assert is_map(pipeline.script)
      assert is_map(pipeline.editing_timeline)
      assert is_map(pipeline.visual_assets.thumbnail)
      assert length(pipeline.visual_assets.end_screens) == 3
      assert length(pipeline.repurposed_package.shorts_scripts) == 3
      assert length(pipeline.repurposed_package.twitter_thread) == 7
      assert length(pipeline.localizations) >= 4
      assert pipeline.ab_experiment.status == :draft
    end
  end
end
