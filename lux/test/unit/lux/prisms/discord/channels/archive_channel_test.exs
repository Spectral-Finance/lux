defmodule Lux.Prisms.Discord.Channels.ArchiveChannelTest do
  @moduledoc """
  Test suite for ArchiveChannel prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.ArchiveChannel

  @channel_id "123456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully archives a channel" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @channel_id,
          "archived" => true,
          "locked" => true
        }))
      end)

      assert {:ok, %{
        archived: true,
        channel_id: @channel_id,
        locked: true
      }} = ArchiveChannel.handler(
        %{
          channel_id: @channel_id,
          lock: true,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end