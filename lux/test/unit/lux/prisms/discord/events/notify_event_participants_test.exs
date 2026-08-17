defmodule Lux.Prisms.Discord.Events.NotifyEventParticipantsTest do
  @moduledoc """
  Test suite for NotifyEventParticipants prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Events.NotifyEventParticipants

  @guild_id "123456789012345678"
  @event_id "222222222222222222"
  @channel_id "333333333333333333"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully notifies event participants" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "444444444444444444",
          "content" => "Event starting soon!",
          "channel_id" => @channel_id
        }))
      end)

      assert {:ok, %{
        notified: true,
        guild_id: @guild_id,
        event_id: @event_id,
        channel_message_id: "444444444444444444",
        dm_count: 0
      }} = NotifyEventParticipants.handler(
        %{
          guild_id: @guild_id,
          event_id: @event_id,
          channel_id: @channel_id,
          message: "Event starting soon!",
          dm_interested: false,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end