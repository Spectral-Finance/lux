defmodule Lux.Prisms.Discord.Moderation.KickMemberTest do
  @moduledoc """
  Test suite for the KickMember module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.KickMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully kicks a member" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/members/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{
        kicked: true,
        user_id: @user_id,
        guild_id: @guild_id
      }} = KickMember.handler(
        %{guild_id: @guild_id, user_id: @user_id},
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

      assert {:error, {403, "Missing Permissions"}} = KickMember.handler(
        %{guild_id: @guild_id, user_id: @user_id},
        @agent_ctx
      )
    end

    test "validates missing guild_id" do
      assert {:error, "Missing or invalid guild_id"} =
        KickMember.handler(%{user_id: @user_id}, @agent_ctx)
    end
  end
end
