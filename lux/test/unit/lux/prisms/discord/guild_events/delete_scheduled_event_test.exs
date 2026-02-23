defmodule Lux.Prisms.Discord.GuildEvents.DeleteScheduledEventTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.GuildEvents.DeleteScheduledEvent

  @guild_id "123456789012345678"
  @event_id "111111111111111111"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes a scheduled event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{deleted: true, event_id: @event_id, guild_id: @guild_id}} =
        DeleteScheduledEvent.handler(
          %{guild_id: @guild_id, event_id: @event_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "handles unknown event error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"message" => "Unknown Scheduled Event"}))
      end)

      assert {:error, {404, "Unknown Scheduled Event"}} =
        DeleteScheduledEvent.handler(
          %{guild_id: @guild_id, event_id: @event_id, plug: {Req.Test, DiscordClientMock}},
          @agent_ctx
        )
    end

    test "returns error when event_id is missing" do
      assert {:error, "Missing or invalid event_id"} =
        DeleteScheduledEvent.handler(%{guild_id: @guild_id}, @agent_ctx)
    end

    test "returns error when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} =
        DeleteScheduledEvent.handler(%{event_id: @event_id}, @agent_ctx)
    end
  end
end
