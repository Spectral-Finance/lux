defmodule Lux.Prisms.Discord.Guilds.AddRoleToMemberTest do
  @moduledoc """
  Test suite for the AddRoleToMember module.
  These tests verify the prism's ability to:
  - Assign roles to members in a Discord guild
  - Handle Discord API errors appropriately
  - Validate input parameters
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Guilds.AddRoleToMember

  @guild_id "123456789012345678"
  @user_id "876543210987654321"
  @role_id "111222333444555666"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully assigns role to member" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}/roles/#{@role_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, response} = AddRoleToMember.handler(
        %{
          guild_id: @guild_id,
          user_id: @user_id,
          role_id: @role_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )

      assert response == %{
        assigned: true,
        role_id: @role_id,
        user_id: @user_id,
        guild_id: @guild_id
      }
    end

    test "handles missing permissions error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}/roles/#{@role_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = AddRoleToMember.handler(
        %{
          guild_id: @guild_id,
          user_id: @user_id,
          role_id: @role_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles unknown member error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}/roles/#{@role_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Member"
        }))
      end)

      assert {:error, {404, "Unknown Member"}} = AddRoleToMember.handler(
        %{
          guild_id: @guild_id,
          user_id: @user_id,
          role_id: @role_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "validates required parameters" do
      assert {:error, "Missing or invalid guild_id"} = AddRoleToMember.handler(
        %{user_id: @user_id, role_id: @role_id},
        @agent_ctx
      )

      assert {:error, "Missing or invalid user_id"} = AddRoleToMember.handler(
        %{guild_id: @guild_id, role_id: @role_id},
        @agent_ctx
      )

      assert {:error, "Missing or invalid role_id"} = AddRoleToMember.handler(
        %{guild_id: @guild_id, user_id: @user_id},
        @agent_ctx
      )
    end

    test "validates non-empty parameters" do
      assert {:error, "Missing or invalid guild_id"} = AddRoleToMember.handler(
        %{guild_id: "", user_id: @user_id, role_id: @role_id},
        @agent_ctx
      )

      assert {:error, "Missing or invalid user_id"} = AddRoleToMember.handler(
        %{guild_id: @guild_id, user_id: "", role_id: @role_id},
        @agent_ctx
      )

      assert {:error, "Missing or invalid role_id"} = AddRoleToMember.handler(
        %{guild_id: @guild_id, user_id: @user_id, role_id: ""},
        @agent_ctx
      )
    end
  end
end
