defmodule Lux.Integrations.YouTube.ContentPipelineTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.ContentPipeline

  @brief %{
    topic: "Build AI agents with Elixir",
    audience: "developers",
    goal: "ship reliable automations",
    key_points: ["Define the workflow", "Add tests", "Deploy safely"],
    summary: "A practical production workflow.",
    keywords: ["Elixir", "AI Agents", "Automation"],
    languages: ["es", "zh"],
    pillar: "Agent Engineering",
    title: "Build AI agents with Elixir"
  }

  describe "script_outline/1" do
    test "builds a structured script outline" do
      outline = ContentPipeline.script_outline(@brief)

      assert outline.hook =~ "Build AI agents"
      assert outline.intro =~ "ship reliable automations"
      assert length(outline.sections) == 3
      assert outline.estimated_minutes == 6
      assert outline.call_to_action =~ "comment"
    end
  end

  describe "editing_suggestions/1" do
    test "suggests edits from script signals" do
      suggestions =
        ContentPipeline.editing_suggestions(%{
          intro_seconds: 30,
          estimated_minutes: 8,
          sections: [%{}, %{}, %{}],
          needs_visual_examples: true
        })

      assert Enum.any?(suggestions, &(&1.type == :intro_trim))
      assert Enum.any?(suggestions, &(&1.type == :pattern_interrupts))
      assert Enum.any?(suggestions, &(&1.type == :chapter_markers))
      assert Enum.any?(suggestions, &(&1.type == :b_roll))
    end
  end

  describe "thumbnail_brief/1" do
    test "builds thumbnail concepts and variants" do
      brief = ContentPipeline.thumbnail_brief(@brief)

      assert brief.concept =~ "Before/after"
      assert brief.focal_text == "Build AI agents with Elixir"
      assert length(brief.variants) == 2
    end
  end

  describe "metadata_plan/1" do
    test "builds title, description, tags, cards, and end screen" do
      metadata = ContentPipeline.metadata_plan(@brief)

      assert metadata.title == "Build AI agents with Elixir"
      assert metadata.description =~ "A practical production workflow."
      assert metadata.description =~ "#elixir"
      assert "ai agents" in metadata.tags
      assert metadata.end_screen.type == :next_video
    end
  end

  describe "playlist_plan/1 and localization_tasks/1" do
    test "builds playlist placement and localization tasks" do
      playlist = ContentPipeline.playlist_plan(@brief)
      assert playlist.playlist == "Agent Engineering"
      assert playlist.position == :end

      tasks = ContentPipeline.localization_tasks(@brief)
      assert [%{language: "es"}, %{language: "zh"}] = tasks
      assert :translate_captions in List.first(tasks).tasks
    end
  end

  describe "repurposing_ideas/1 and ab_test_plan/1" do
    test "builds repurposing ideas and A/B plans" do
      ideas = ContentPipeline.repurposing_ideas(@brief)
      assert Enum.any?(ideas, &(&1.format == :short))
      assert Enum.any?(ideas, &(&1.format == :newsletter))

      plan =
        ContentPipeline.ab_test_plan(%{
          title: "Build AI agents with Elixir",
          title_b: "Reliable Elixir agents in production",
          thumbnail_a: "thumb-a",
          thumbnail_b: "thumb-b"
        })

      assert plan.metric == :click_through_rate
      assert plan.minimum_runtime_hours == 24
      assert [%{id: "A"}, %{id: "B", title: "Reliable Elixir agents in production"}] = plan.variants
    end
  end

  describe "pipeline/1" do
    test "builds the full content creation pipeline" do
      pipeline = ContentPipeline.pipeline(@brief)

      assert pipeline.script.estimated_minutes == 6
      assert pipeline.thumbnail.focal_text == "Build AI agents with Elixir"
      assert "automation" in pipeline.metadata.tags
      assert pipeline.playlist.playlist == "Agent Engineering"
      assert length(pipeline.localization) == 2
      assert length(pipeline.repurposing) == 3
      assert pipeline.ab_test.metric == :click_through_rate
    end
  end
end
