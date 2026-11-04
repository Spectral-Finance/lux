defmodule Lux.Beams.Discord.DiscordSignalPipelineBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Discord.Signals.DiscordSignalPipelineBeam

  describe "DiscordSignalPipelineBeam" do
    test "has expected metadata" do
      assert DiscordSignalPipelineBeam.name() == "DiscordSignalPipelineBeam" ||
             DiscordSignalPipelineBeam.name() == "Discord Signal Pipeline Beam"
      assert is_binary(DiscordSignalPipelineBeam.description())
      assert is_map(DiscordSignalPipelineBeam.input_schema())
      assert is_map(DiscordSignalPipelineBeam.output_schema())
    end

    test "beam steps are configured properly" do
      steps = DiscordSignalPipelineBeam.steps()
      assert is_list(steps)
      assert length(steps) >= 3

      step_ids = Enum.map(steps, & &1.id)
      assert :parse_event in step_ids
      assert :validate_signal in step_ids
      assert :route_signal in step_ids
      assert :emit_response in step_ids
    end
  end
end
