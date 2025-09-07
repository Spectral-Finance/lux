defmodule Lux.Prisms.Discord.Guilds.BanMemberTest do
  @moduledoc """
  Test suite for the BanMember module.
  These tests verify the prism's ability to:
  - Ban a member from a Discord server
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Guilds.BanMember

  @guild_id "987654321098765432"
  @user_id "123456789012345678"
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
        guild_id: @guild_id,
        user_id: @user_id
      }} = BanMember.handler(
        %{
          guild_id: @guild_id,
          user_id: @user_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "fails when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} = BanMember.handler(
        %{user_id: @user_id},
        @agent_ctx
      )
    end

    test "fails when user_id is missing" do
      assert {:error, "Missing or invalid user_id"} = BanMember.handler(
        %{guild_id: @guild_id},
        @agent_ctx
      )
    end

    test "fails when Discord returns an error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "code" => 50_013,
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, _} = BanMember.handler(
        %{
          guild_id: @guild_id,
          user_id: @user_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end
