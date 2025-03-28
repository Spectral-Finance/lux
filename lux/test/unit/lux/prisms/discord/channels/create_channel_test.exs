defmodule Lux.Prisms.Discord.Channels.CreateChannelTest do
  @moduledoc """
  Test suite for the CreateChannel module.
  These tests verify the prism's ability to:
  - Create channels in a Discord guild
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.CreateChannel

  @guild_id "123456789012345678"
  @channel_name "test-channel"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/channels"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "name" => @channel_name,
          "type" => 0
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "id" => "111111111111111111",
          "name" => @channel_name,
          "type" => 0,
          "guild_id" => @guild_id
        }))
      end)

      assert {:ok, %{
        created: true,
        channel_id: "111111111111111111",
        name: @channel_name,
        type: 0,
        guild_id: @guild_id
      }} = CreateChannel.handler(
        %{
          guild_id: @guild_id,
          name: @channel_name,
          type: 0,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/channels"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = CreateChannel.handler(
        %{
          guild_id: @guild_id,
          name: @channel_name,
          type: 0,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end
