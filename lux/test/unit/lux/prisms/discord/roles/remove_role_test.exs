defmodule Lux.Prisms.Discord.Roles.RemoveRoleTest do
  @moduledoc """
  Test suite for RemoveRole prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Roles.RemoveRole

  @guild_id "123456789012345678"
  @user_id "111222333444555666"
  @role_id "999888777666"
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully removes a role" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}/roles/#{@role_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{removed: true, guild_id: @guild_id, user_id: @user_id, role_id: @role_id}} =
               RemoveRole.handler(
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
        assert conn.method == "DELETE"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               RemoveRole.handler(
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
