defmodule Lux.Agent.DiscordCapabilitiesTest do
  use UnitCase, async: true

  alias Lux.Agents.DiscordAgent

  describe "DiscordAgent configuration" do
    test "has expected capabilities and metadata" do
      assert DiscordAgent.name() == "Discord Community & Server Management Agent"
      assert is_binary(DiscordAgent.description())
      assert is_binary(DiscordAgent.goal())

      capabilities = DiscordAgent.capabilities()
      assert :server_management in capabilities
      assert :conversation_moderation in capabilities
      assert :role_assignment in capabilities
      assert :member_interaction in capabilities
    end

    test "includes dedicated Discord prisms" do
      prisms = DiscordAgent.prisms()
      assert Lux.Prisms.Discord.ServerManagementPrism in prisms
      assert Lux.Prisms.Discord.ConversationPrism in prisms
      assert Lux.Prisms.Discord.RoleManagementPrism in prisms
      assert Lux.Prisms.Discord.MemberInteractionPrism in prisms
    end
  end
end
