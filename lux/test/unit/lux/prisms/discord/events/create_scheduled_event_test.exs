defmodule Lux.Prisms.Discord.Events.CreateScheduledEventTest do
  @moduledoc """
  Test suite for the CreateScheduledEvent prism (lux issue #57).
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Events.CreateScheduledEvent

  @guild_id "123456789012345678"
  @event_id "111111111111111111"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a scheduled event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "Community Standup"
        assert decoded["scheduled_start_time"] == "2026-12-01T10:00:00Z"
        assert decoded["privacy_level"] == 2

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @event_id}))
      end)

      assert {:ok, result} =
               CreateScheduledEvent.handler(
                 %{
                   guild_id: @guild_id,
                   name: "Community Standup",
                   scheduled_start_time: "2026-12-01T10:00:00Z",
                   entity_type: 3,
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )

      assert result.scheduled == true
      assert result.event_id == @event_id
      assert result.name == "Community Standup"
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"message" => "Invalid start time"}))
      end)

      assert {:error, {400, "Invalid start time"}} =
               CreateScheduledEvent.handler(
                 %{
                   guild_id: @guild_id,
                   name: "Bad Event",
                   scheduled_start_time: "not-a-date",
                   plug: {Req.Test, DiscordClientMock}
                 },
                 @agent_ctx
               )
    end

    test "rejects missing name" do
      assert {:error, msg} =
               CreateScheduledEvent.handler(
                 %{guild_id: @guild_id, scheduled_start_time: "2026-12-01T10:00:00Z"},
                 @agent_ctx
               )

      assert is_binary(msg)
    end
  end
end