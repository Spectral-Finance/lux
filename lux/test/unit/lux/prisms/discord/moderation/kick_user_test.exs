defmodule Lux.Prisms.Discord.Moderation.KickUserTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.KickUser

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully kicks a user" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{kicked: true, user_id: @user_id, guild_id: @guild_id}} =
        KickUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "handles missing permissions error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
        KickUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "returns error when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} =
        KickUser.handler(%{user_id: @user_id}, @agent_ctx)
    end

    test "returns error when user_id is missing" do
      assert {:error, "Missing or invalid user_id"} =
        KickUser.handler(%{guild_id: @guild_id}, @agent_ctx)
    end
  end
end
