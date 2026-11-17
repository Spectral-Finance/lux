defmodule Lux.Lenses.Discord.Events.GetScheduledEventTest do
  @moduledoc """
  Test suite for the GetScheduledEvent module.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Events.GetScheduledEvent

  @guild_id "123456789012345678"
  @event_id "111111111111111111"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches a scheduled event" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/scheduled-events/:event_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => "Community Meetup",
          "description" => "Weekly gathering",
          "scheduled_start_time" => "2024-12-25T18:00:00+00:00",
          "scheduled_end_time" => "2024-12-25T20:00:00+00:00",
          "status" => 1,
          "entity_type" => 3,
          "user_count" => 42,
          "creator" => %{"id" => "222222222222222222"}
        }))
      end)

      assert {:ok, event} = GetScheduledEvent.focus(%{
        guild_id: @guild_id,
        event_id: @event_id
      }, %{})

      assert event.id == @event_id
      assert event.name == "Community Meetup"
      assert event.description == "Weekly gathering"
      assert event.status == 1
      assert event.user_count == 42
      assert event.creator_id == "222222222222222222"
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Guild Scheduled Event"
        }))
      end)

      assert {:error, %{"message" => "Unknown Guild Scheduled Event"}} =
        GetScheduledEvent.focus(%{guild_id: @guild_id, event_id: @event_id}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = GetScheduledEvent.view()
      assert lens.schema.required == ["guild_id", "event_id"]
    end
  end
end
