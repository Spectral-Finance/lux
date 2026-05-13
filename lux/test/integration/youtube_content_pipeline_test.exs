defmodule Lux.Integration.YouTubeContentPipelineTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.YouTube.ContentPipeline
  alias Lux.Prisms.YouTube.CreateContentPipeline

  test "showcases an end-to-end content creation workflow" do
    brief = %{
      "topic" => "agentic trading risk reviews",
      "target_audience" => "DeFi operators",
      "goal" => "ship safer trading automations",
      "duration_minutes" => 12,
      "keywords" => ["agentic trading", "risk review", "DeFi automation"],
      "languages" => ["en", "ja", "es"],
      "existing_playlists" => ["DeFi automation", "Operator security"],
      "assets" => ["risk matrix", "demo dashboard"]
    }

    assert {:ok, pipeline} = ContentPipeline.run(brief)
    assert {:ok, prism_pipeline} = CreateContentPipeline.run(brief)

    assert pipeline.script.sections == prism_pipeline.script.sections
    assert pipeline.metadata.description =~ "DeFi operators"
    assert pipeline.visual_optimization.thumbnail.variants |> Enum.map(& &1.name) == ["Outcome", "Tension", "Curiosity"]
    assert pipeline.playlist.primary_playlist == "DeFi automation"
    assert pipeline.localization.languages |> Enum.map(& &1.language) == ["en", "ja", "es"]
    assert Enum.any?(pipeline.repurposing.social_posts, &String.contains?(&1, "agentic trading risk reviews"))
    assert Enum.all?(pipeline.testing.experiments, &(&1.min_runtime_days >= 7))
    assert pipeline.handoff.owners.metadata == "channel manager"
  end
end
