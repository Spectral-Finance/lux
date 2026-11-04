defmodule Lux.Prisms.Discord.AgentDiscordCapabilitiesTest do
  use UnitAPICase, async: true

  alias Lux.Beams.Discord.GuildOperationsBeam
  alias Lux.Lenses.Discord.Guilds.GuildActivityLens
  alias Lux.Prisms.Discord.Members.ManageMember
  alias Lux.Prisms.Discord.Roles.ManageRole

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "ManageRole Prism" do
    test "creates a custom guild role with permissions" do
      Req.Test.expect(Lux.Integrations.Discord.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/123456789012345678/roles"

        Req.Test.json(conn, %{
          "id" => "555555555555555555",
          "name" => "Core Validator",
          "permissions" => "8"
        })
      end)

      assert {:ok,
              %{
                success: true,
                action: "create",
                guild_id: "123456789012345678",
                role_id: "555555555555555555",
                name: "Core Validator"
              }} =
               ManageRole.handler(
                 %{
                   action: "create",
                   guild_id: "123456789012345678",
                   name: "Core Validator",
                   permissions: "8"
                 },
                 %{name: "DiscordAgent"}
               )
    end

    test "assigns a role to a guild member" do
      Req.Test.expect(Lux.Integrations.Discord.Client, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/123456789012345678/members/888888888888888888/roles/555555555555555555"
        Req.Test.json(conn, %{})
      end)

      assert {:ok, %{success: true, action: "assign", role_id: "555555555555555555"}} =
               ManageRole.handler(
                 %{
                   action: "assign",
                   guild_id: "123456789012345678",
                   user_id: "888888888888888888",
                   role_id: "555555555555555555"
                 },
                 %{name: "DiscordAgent"}
               )
    end
  end

  describe "ManageMember Prism" do
    test "sends a direct message to a Discord user" do
      Req.Test.expect(Lux.Integrations.Discord.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/users/@me/channels"
        Req.Test.json(conn, %{"id" => "777777777777777777"})
      end)

      Req.Test.expect(Lux.Integrations.Discord.Client, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/777777777777777777/messages"
        Req.Test.json(conn, %{"id" => "999999999999999999", "content" => "Welcome to Lux!"})
      end)

      assert {:ok,
              %{
                success: true,
                action: "direct_message",
                dm_channel_id: "777777777777777777",
                message_id: "999999999999999999"
              }} =
               ManageMember.handler(
                 %{
                   action: "direct_message",
                   user_id: "888888888888888888",
                   content: "Welcome to Lux!"
                 },
                 %{name: "DiscordAgent"}
               )
    end
  end

  describe "GuildActivityLens & GuildOperationsBeam" do
    test "transforms guild role hierarchy in after_focus/1" do
      raw = %{
        "id" => "123456789012345678",
        "name" => "Spectral Hub",
        "owner_id" => "111",
        "approximate_member_count" => 42,
        "roles" => [
          %{"id" => "r1", "name" => "Member", "permissions" => "0", "position" => 1},
          %{"id" => "r2", "name" => "Admin", "permissions" => "8", "position" => 10}
        ]
      }

      assert {:ok, %{guild_id: "123456789012345678", roles: [first_role | _]}} =
               GuildActivityLens.after_focus(raw)

      assert first_role.name == "Admin"
    end

    test "exposes valid GuildOperationsBeam view specification" do
      beam = GuildOperationsBeam.view()
      assert beam.name == "Discord Guild Operations Beam"
    end
  end
end
