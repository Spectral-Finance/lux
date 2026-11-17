defmodule Lux.Prisms.Discord.Moderation.UnbanMemberTest do
  @moduledoc """
  Test suite for the UnbanMember module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.UnbanMember

  @guild_id "123456789012345678"
  @user_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unbans a member" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/bans/#{@user_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{
        unbanned: true,
        user_id: @user_id,
        guild_id: @guild_id
      }} = UnbanMember.handler(
        %{guild_id: @guild_id, user_id: @user_id},
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Ban"
        }))
      end)

      assert {:error, {404, "Unknown Ban"}} = UnbanMember.handler(
        %{guild_id: @guild_id, user_id: @user_id},
        @agent_ctx
      )
    end

    test "validates missing user_id" do
      assert {:error, "Missing or invalid user_id"} =
        UnbanMember.handler(%{guild_id: @guild_id}, @agent_ctx)
    end
  end
end
