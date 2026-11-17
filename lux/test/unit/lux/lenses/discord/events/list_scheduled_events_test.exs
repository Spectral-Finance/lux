defmodule Lux.Lenses.Discord.Events.ListScheduledEventsTest do
  @moduledoc """
  Test suite for the ListScheduledEvents module.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Events.ListScheduledEvents

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists scheduled events" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/scheduled-events"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "111111111111111111",
            "name" => "Community Meetup",
            "description" => "Weekly gathering",
            "scheduled_start_time" => "2024-12-25T18:00:00+00:00",
            "scheduled_end_time" => "2024-12-25T20:00:00+00:00",
            "status" => 1,
            "entity_type" => 3,
            "creator" => %{"id" => "222222222222222222"}
          }
        ]))
      end)

      assert {:ok, events} = ListScheduledEvents.focus(%{guild_id: @guild_id}, %{})
      assert length(events) == 1
      [event] = events
      assert event.id == "111111111111111111"
      assert event.name == "Community Meetup"
      assert event.status == 1
      assert event.entity_type == 3
      assert event.creator_id == "222222222222222222"
    end

    test "handles empty events list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = ListScheduledEvents.focus(%{guild_id: @guild_id}, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
        ListScheduledEvents.focus(%{guild_id: @guild_id}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = ListScheduledEvents.view()
      assert lens.schema.required == ["guild_id"]
    end
  end
end
