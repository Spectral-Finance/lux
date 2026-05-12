defmodule Lux.Prisms.Discord.Role.DeleteRoleTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Role.DeleteRole

  @guild_id "123456789012345678"
  @role_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "deletes a role" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/roles/#{@role_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, Jason.encode!(%{}))
      end)

      assert {:ok, %{deleted: true, guild_id: @guild_id, role_id: @role_id}} =
               DeleteRole.handler(%{guild_id: @guild_id, role_id: @role_id}, @agent_ctx)
    end

    test "handles Discord API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/roles/#{@role_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               DeleteRole.handler(%{guild_id: @guild_id, role_id: @role_id}, @agent_ctx)
    end
  end
end
