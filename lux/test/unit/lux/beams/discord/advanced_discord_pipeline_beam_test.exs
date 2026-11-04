defmodule Lux.Beams.Discord.AdvancedDiscordPipelineBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Discord.AdvancedDiscordPipelineBeam

  describe "AdvancedDiscordPipelineBeam" do
    test "has expected metadata" do
      assert AdvancedDiscordPipelineBeam.name() == "AdvancedDiscordPipelineBeam" ||
             AdvancedDiscordPipelineBeam.name() == "Advanced Discord Pipeline Beam"
      assert is_binary(AdvancedDiscordPipelineBeam.description())
      assert is_map(AdvancedDiscordPipelineBeam.input_schema())
      assert is_map(AdvancedDiscordPipelineBeam.output_schema())
    end

    test "beam steps are configured properly" do
      steps = AdvancedDiscordPipelineBeam.steps()
      assert is_list(steps)
      assert length(steps) >= 3

      step_ids = Enum.map(steps, & &1.id)
      assert :sync_presence in step_ids
      assert :join_voice in step_ids
      assert :log_telemetry in step_ids
      assert :notify_webhook in step_ids
    end
  end
end
