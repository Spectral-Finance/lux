defmodule Lux.YouTube.ContentCreation.VisualOptimizerTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentCreation.VisualOptimizer

  describe "generate_thumbnail_spec/2" do
    test "generates high contrast prompt and color palette" do
      spec = VisualOptimizer.generate_thumbnail_spec("Distributed Elixir Systems", %{badge_text: "10X SCALE"})

      assert spec.badge_text == "10X SCALE"
      assert is_binary(spec.prompt_for_ai_generator)
      assert String.contains?(spec.prompt_for_ai_generator, "Distributed Elixir Systems")
      assert length(spec.primary_palette) >= 3
      assert spec.contrast_ratio_target >= 4.5
    end
  end

  describe "build_end_screen_layout/1" do
    test "places end screen elements in final 20 seconds" do
      elements = VisualOptimizer.build_end_screen_layout(600)

      assert length(elements) == 3
      first = List.first(elements)
      assert first.start_offset_seconds == 580
      assert first.end_offset_seconds == 600
    end
  end

  describe "plan_info_cards/2" do
    test "calculates teaser card timestamps strategically" do
      cards = VisualOptimizer.plan_info_cards(600, ["Part 2", "Playlist"])

      assert length(cards) == 2
      first = List.first(cards)
      assert first.timestamp == "02:30"
      assert String.contains?(first.teaser_text, "Part 2")
    end
  end
end
