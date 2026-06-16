defmodule Lux.Prisms.Discord.Moderation.BanMemberTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Moderation.BanMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "bans a guild member and sends delete window to Discord" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"
      assert Plug.Conn.get_req_header(conn, "x-audit-log-reason") == ["raid%20cleanup"]
      assert Jason.decode!(body) == %{"delete_message_seconds" => 3600}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(204, Jason.encode!(%{}))
    end)

    assert {:ok, %{banned: true, guild_id: @guild_id, user_id: @user_id}} =
             BanMember.handler(
               %{
                 guild_id: @guild_id,
                 user_id: @user_id,
                 delete_message_seconds: 3600,
                 reason: "raid cleanup"
               },
               %{}
             )
  end

  test "rejects invalid delete message seconds" do
    assert {:error, "Missing or invalid delete_message_seconds"} =
             BanMember.handler(
               %{guild_id: @guild_id, user_id: @user_id, delete_message_seconds: 604_801},
               %{}
             )
  end
end
