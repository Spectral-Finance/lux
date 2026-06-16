defmodule Lux.Prisms.Discord.Events.CreateScheduledEventTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Events.CreateScheduledEvent

  @guild_id "123456789012345678"
  @event_id "222222222222222222"
  @start_time "2026-06-15T18:00:00Z"
  @end_time "2026-06-15T19:00:00Z"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "creates an external scheduled event" do
    Req.Test.expect(DiscordClientMock, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"

      assert Jason.decode!(body) == %{
               "name" => "Launch review",
               "scheduled_start_time" => @start_time,
               "scheduled_end_time" => @end_time,
               "description" => "Review launch checklist",
               "entity_type" => 3,
               "privacy_level" => 2,
               "entity_metadata" => %{"location" => "Discord voice + livestream"}
             }

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => @event_id, "name" => "Launch review"}))
    end)

    assert {:ok,
            %{
              created: true,
              event_id: @event_id,
              guild_id: @guild_id,
              name: "Launch review"
            }} =
             CreateScheduledEvent.handler(
               %{
                 guild_id: @guild_id,
                 name: "Launch review",
                 scheduled_start_time: @start_time,
                 scheduled_end_time: @end_time,
                 description: "Review launch checklist",
                 entity_type: 3,
                 location: "Discord voice + livestream"
               },
               %{}
             )
  end

  test "requires a channel for voice events" do
    assert {:error, "Missing or invalid channel_id"} =
             CreateScheduledEvent.handler(
               %{
                 guild_id: @guild_id,
                 name: "Standup",
                 scheduled_start_time: @start_time,
                 entity_type: 2
               },
               %{}
             )
  end
end
