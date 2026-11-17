defmodule Lux.Prisms.Discord.Moderation.BanMemberTest do
  @moduledoc """
  Test suite for the BanMember module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.BanMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully bans a member" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{
        banned: true,
        user_id: @user_id,
        guild_id: @guild_id
      }} = BanMember.handler(
        %{guild_id: @guild_id, user_id: @user_id},
        @agent_ctx
      )
    end

    test "bans with message deletion" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PUT"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["delete_message_seconds"] == 86400

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{banned: true}} = BanMember.handler(
        %{guild_id: @guild_id, user_id: @user_id, delete_message_seconds: 86400},
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = BanMember.handler(
        %{guild_id: @guild_id, user_id: @user_id},
        @agent_ctx
      )
    end

    test "validates missing guild_id" do
      assert {:error, "Missing or invalid guild_id"} =
        BanMember.handler(%{user_id: @user_id}, @agent_ctx)
    end
  end
end
