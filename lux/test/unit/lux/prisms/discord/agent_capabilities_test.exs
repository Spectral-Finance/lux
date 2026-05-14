defmodule Lux.Prisms.Discord.AgentCapabilitiesTest do
  use UnitCase, async: true

  alias Lux.Prisms.Discord.AgentCapabilities

  test "returns a Discord agent capability plan" do
    assert {:ok, plan} =
             AgentCapabilities.handler(
               %{
                 guild_id: "123456789012345678",
                 channel_id: "234567890123456789",
                 member_id: "345678901234567890",
                 role_id: "456789012345678901",
                 agent_roles: ["admin"]
               },
               %{agent: %{name: "DiscordAgent"}}
             )

    assert plan.server_management.operations != []
    assert plan.conversation_management.operations != []
    assert plan.role_management.operations != []
    assert plan.member_interaction.operations != []
    assert plan.behavior_policy.role_adaptation[:can_manage_roles?]
  end

  test "exposes prism schema" do
    view = AgentCapabilities.view()

    assert view.name == "Discord Agent Capabilities"
    assert Map.has_key?(view.input_schema.properties, :guild_id)
    assert "server_management" in view.output_schema.required
  end
end
