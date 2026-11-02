defmodule Lux.YouTube.ContentCreation.ScriptGeneratorTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentCreation.ScriptGenerator

  describe "generate_script/1" do
    test "generates structured script with hook, body chapters, and CTA" do
      script =
        ScriptGenerator.generate_script(%{
          topic: "Autonomous Multi-Agent Architecture",
          format: :tutorial,
          target_minutes: 10.0,
          channel_name: "Lux Academy"
        })

      assert String.contains?(script.title, "Autonomous Multi-Agent Architecture")
      assert is_binary(script.hook)
      assert is_binary(script.cta)
      assert script.total_word_count > 100
      assert script.estimated_duration_minutes > 0.0
      assert length(script.sections) >= 4

      # Verify chapter timestamps and director notes
      first_section = List.first(script.sections)
      assert first_section.timestamp_estimate == "00:00"
      assert is_binary(first_section.director_notes)
    end
  end
end
