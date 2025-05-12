defmodule Lux.Prisms.Discord.Channels.DeleteChannelTest do
  @moduledoc """
  Test suite for the DeleteChannel module.
  These tests verify the prism's ability to:
  - Delete channels from a Discord guild
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.DeleteChannel

  @channel_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes a channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @channel_id,
          "name" => "deleted-channel",
          "type" => 0,
          "guild_id" => "987654321098765432"
        }))
      end)

      assert {:ok, %{
        deleted: true,
        channel_id: @channel_id
      }} = DeleteChannel.handler(
        %{
          channel_id: @channel_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = DeleteChannel.handler(
        %{
          channel_id: @channel_id,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end
