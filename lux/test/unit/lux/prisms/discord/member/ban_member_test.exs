defmodule Lux.Prisms.Discord.Member.BanMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Member.BanMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "bans a member with optional delete-message window" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"delete_message_seconds" => 3600}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, Jason.encode!(%{}))
      end)

      assert {:ok,
              %{
                banned: true,
                guild_id: @guild_id,
                user_id: @user_id,
                delete_message_seconds: 3600
              }} =
               BanMember.handler(
                 %{guild_id: @guild_id, user_id: @user_id, delete_message_seconds: 3600},
                 @agent_ctx
               )
    end

    test "handles Discord API errors" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, {403, "Missing Permissions"}} =
               BanMember.handler(%{guild_id: @guild_id, user_id: @user_id}, @agent_ctx)
    end
  end
end
