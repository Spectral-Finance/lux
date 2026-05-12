defmodule Lux.Prisms.Discord.Member.KickMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Member.KickMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "removes a member from a guild" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, Jason.encode!(%{}))
      end)

      assert {:ok, %{kicked: true, guild_id: @guild_id, user_id: @user_id}} =
               KickMember.handler(%{guild_id: @guild_id, user_id: @user_id}, @agent_ctx)
    end

    test "handles Discord API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               KickMember.handler(%{guild_id: @guild_id, user_id: @user_id}, @agent_ctx)
    end
  end
end
