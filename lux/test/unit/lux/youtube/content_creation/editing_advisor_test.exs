defmodule Lux.YouTube.ContentCreation.EditingAdvisorTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentCreation.EditingAdvisor

  describe "generate_editing_cues/1" do
    test "constructs detailed edit cues with visual actions, cuts, and audio specs" do
      sections = [
        %{name: "Hook & Stake", timestamp_estimate: "00:00"},
        %{name: "Live Implementation", timestamp_estimate: "03:00"},
        %{name: "Call to Action", timestamp_estimate: "09:00"}
      ]

      timeline = EditingAdvisor.generate_editing_cues(sections)

      assert timeline.total_cues >= 3
      assert timeline.recommended_cut_frequency_seconds > 0.0
      assert timeline.audio_mastering_specs.target_loudness_lufs == -14.0

      cue = List.first(timeline.cues)
      assert is_binary(cue.visual_action)
      assert is_binary(cue.sound_effect)
      assert is_binary(cue.editor_tip)
      assert is_atom(cue.camera_framing)
    end
  end
end
