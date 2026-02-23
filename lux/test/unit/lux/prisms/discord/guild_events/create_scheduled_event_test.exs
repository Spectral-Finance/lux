defmodule Lux.Prisms.Discord.GuildEvents.CreateScheduledEventTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.GuildEvents.CreateScheduledEvent

  @guild_id "123456789012345678"
  @event_id "111111111111111111"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates an external scheduled event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "Team Meeting"
        assert decoded["entity_type"] == 3
        assert decoded["privacy_level"] == 2

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => "Team Meeting",
          "guild_id" => @guild_id
        }))
      end)

      assert {:ok, %{created: true, event_id: @event_id, name: "Team Meeting"}} =
        CreateScheduledEvent.handler(
          %{
            guild_id: @guild_id,
            name: "Team Meeting",
            scheduled_start_time: "2026-03-01T14:00:00Z",
            entity_type: 3,
            privacy_level: 2,
            entity_metadata: %{location: "https://meet.example.com"},
            plug: {Req.Test, DiscordClientMock}
          },
          @agent_ctx
        )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"message" => "Missing field: entity_metadata"}))
      end)

      assert {:error, {400, "Missing field: entity_metadata"}} =
        CreateScheduledEvent.handler(
          %{
            guild_id: @guild_id,
            name: "Meeting",
            scheduled_start_time: "2026-03-01T14:00:00Z",
            entity_type: 3,
            privacy_level: 2,
            plug: {Req.Test, DiscordClientMock}
          },
          @agent_ctx
        )
    end

    test "returns error when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} =
        CreateScheduledEvent.handler(
          %{name: "Meeting", scheduled_start_time: "2026-03-01T14:00:00Z", entity_type: 3, privacy_level: 2},
          @agent_ctx
        )
    end

    test "returns error when name is missing" do
      assert {:error, "Missing or invalid name"} =
        CreateScheduledEvent.handler(
          %{guild_id: @guild_id, scheduled_start_time: "2026-03-01T14:00:00Z", entity_type: 3, privacy_level: 2},
          @agent_ctx
        )
    end
  end
end
