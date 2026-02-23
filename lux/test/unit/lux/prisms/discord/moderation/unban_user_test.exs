defmodule Lux.Prisms.Discord.Moderation.UnbanUserTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.UnbanUser

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unbans a user" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{unbanned: true, user_id: @user_id, guild_id: @guild_id}} =
        UnbanUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "handles unknown ban error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"message" => "Unknown Ban"}))
      end)

      assert {:error, {404, "Unknown Ban"}} =
        UnbanUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "returns error when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} =
        UnbanUser.handler(%{user_id: @user_id}, @agent_ctx)
    end

    test "returns error when user_id is missing" do
      assert {:error, "Missing or invalid user_id"} =
        UnbanUser.handler(%{guild_id: @guild_id}, @agent_ctx)
    end
  end
end
