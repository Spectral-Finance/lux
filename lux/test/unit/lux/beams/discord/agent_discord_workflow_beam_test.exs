defmodule Lux.Beams.Discord.AgentDiscordWorkflowBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Discord.AgentDiscordWorkflowBeam

  describe "AgentDiscordWorkflowBeam" do
    test "has expected metadata" do
      assert AgentDiscordWorkflowBeam.name() == "AgentDiscordWorkflowBeam" ||
             AgentDiscordWorkflowBeam.name() == "Agent Discord Workflow Beam"
      assert is_binary(AgentDiscordWorkflowBeam.description())
      assert is_map(AgentDiscordWorkflowBeam.input_schema())
      assert is_map(AgentDiscordWorkflowBeam.output_schema())
    end

    test "beam steps are configured properly" do
      steps = AgentDiscordWorkflowBeam.steps()
      assert is_list(steps)
      assert length(steps) >= 3

      step_ids = Enum.map(steps, & &1.id)
      assert :audit_server in step_ids
      assert :fetch_messages in step_ids
      assert :analyze_sentiment in step_ids
      assert :profile_member in step_ids
    end
  end
end
