defmodule Lux.Integrations.YouTube.ContentPipelineTest do
  use UnitCase, async: true

  alias Lux.Integrations.YouTube.ContentPipeline

  describe "build/1" do
    test "builds a complete YouTube content creation pipeline" do
      assert {:ok, pipeline} = ContentPipeline.build(brief())

      assert pipeline.script.hook =~ "wallet security"
      assert length(pipeline.script.sections) == 4
      assert pipeline.editing.pacing.target_cut_interval_seconds == 6
      assert length(pipeline.visual_optimization.thumbnail.variants) == 3
      assert length(pipeline.metadata.cards) == 3
      assert pipeline.metadata.end_screen.primary_slot =~ "crypto founders"
      assert pipeline.playlist.primary_playlist == "Security for crypto founders"
      assert length(pipeline.localization.languages) == 2
      assert length(pipeline.repurposing.shorts) == 3
      assert length(pipeline.testing.experiments) == 3
      assert "A/B test sheet initialized" in pipeline.handoff.publish_checklist
    end

    test "accepts string keys and default optional values" do
      assert {:ok, pipeline} =
               ContentPipeline.build(%{
                 "topic" => "creator analytics",
                 "target_audience" => "indie creators",
                 "goal" => "choose better video ideas"
               })

      assert pipeline.brief.duration_minutes == 8
      assert pipeline.brief.languages == ["en"]
      assert pipeline.brief.keywords == ["creator analytics"]
      assert pipeline.metadata.tags == ["creator analytics", "indie creators", "tutorial"]
    end

    test "returns missing required fields" do
      assert {:error, {:missing_fields, [:target_audience, :goal]}} =
               ContentPipeline.build(%{topic: "retention"})
    end
  end

  describe "pipeline stages" do
    test "creates metadata, playlist, localization, repurposing, and testing plans" do
      brief = brief()

      metadata = ContentPipeline.metadata_plan(brief)
      playlist = ContentPipeline.playlist_plan(brief)
      localization = ContentPipeline.localization_plan(brief)
      repurposing = ContentPipeline.repurposing_plan(brief)
      testing = ContentPipeline.testing_plan(brief)

      assert Enum.any?(metadata.title_variants, &String.contains?(&1, "Wallet Security"))
      assert Enum.any?(metadata.chapters, &(&1.timestamp == "0:00"))
      assert playlist.create_if_missing == false
      assert Enum.map(localization.languages, & &1.language) == ["en", "es"]
      assert repurposing.newsletter.subject =~ "Wallet Security"
      assert Enum.any?(testing.experiments, &(&1.name == "thumbnail angle"))
    end
  end

  defp brief do
    %{
      topic: "wallet security",
      target_audience: "crypto founders",
      goal: "reduce signing mistakes before launch",
      tone: "direct and practical",
      format: "tutorial",
      duration_minutes: 10,
      keywords: ["hardware wallets", "transaction simulation"],
      languages: ["en", "es"],
      existing_playlists: ["Security for crypto founders", "Launch operations"],
      assets: ["demo wallet", "transaction screenshots"],
      cta: "Download the pre-launch wallet checklist."
    }
  end
end
