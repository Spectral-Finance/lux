defmodule Lux.Prisms.Discord.Role.ListRolesTest do
  @moduledoc """
  Test suite for ListRoles prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Role.ListRoles

  @guild_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully lists guild roles" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/roles"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111111111111111111",
          "name" => "Admin",
          "color" => 16711680,
          "hoist" => true,
          "position" => 5,
          "permissions" => "8",
          "managed" => false,
          "mentionable" => true
        }))
      end)

      assert {:ok, %{
        roles: [%{
          id: "111111111111111111",
          name: "Admin",
          color: 16711680,
          hoist: true,
          position: 5,
          permissions: "8",
          managed: false,
          mentionable: true
        }]
      }} = ListRoles.handler(
        %{
          guild_id: @guild_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/roles"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = ListRoles.handler(
        %{
          guild_id: @guild_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end