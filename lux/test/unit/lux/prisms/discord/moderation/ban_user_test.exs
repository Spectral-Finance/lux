defmodule Lux.Prisms.Discord.Moderation.BanUserTest do
  @moduledoc """
  Test suite for the BanUser prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.BanUser

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully bans a user" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{banned: true, user_id: @user_id, guild_id: @guild_id}} =
        BanUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "bans a user with delete_message_seconds" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"delete_message_seconds" => 86400}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{banned: true}} =
        BanUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, delete_message_seconds: 86400, plug: {Req.Test, DiscordClientMock}},
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
        BanUser.handler(
          %{guild_id: @guild_id, user_id: @user_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "returns error when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} =
        BanUser.handler(%{user_id: @user_id}, @agent_ctx)
    end

    test "returns error when user_id is missing" do
      assert {:error, "Missing or invalid user_id"} =
        BanUser.handler(%{guild_id: @guild_id}, @agent_ctx)
    end
  end
end
