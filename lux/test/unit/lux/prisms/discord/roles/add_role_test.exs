defmodule Lux.Prisms.Discord.Roles.AddRoleTest do
  @moduledoc """
  Test suite for AddRole prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Roles.AddRole

  @guild_id "123456789012345678"
  @user_id "111222333444555666"
  @role_id "999888777666"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully adds a role" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}/roles/#{@role_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{added: true, guild_id: @guild_id, user_id: @user_id, role_id: @role_id}} =
               AddRole.handler(
                 %{
                   guild_id: @guild_id,
                   user_id: @user_id,
                   role_id: @role_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end

    test "handles error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               AddRole.handler(
                 %{
                   guild_id: @guild_id,
                   user_id: @user_id,
                   role_id: @role_id,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end
  end
end
