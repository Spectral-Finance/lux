defmodule Lux.Lenses.Discord.GuildEvents.ListScheduledEventsTest do
  @moduledoc """
  Test suite for the ListScheduledEvents lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.GuildEvents.ListScheduledEvents

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists scheduled events" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "id" => "111111111111111111",
            "name" => "Team Meeting",
            "description" => "Weekly sync",
            "scheduled_start_time" => "2026-03-01T14:00:00Z",
            "scheduled_end_time" => "2026-03-01T15:00:00Z",
            "status" => 1,
            "entity_type" => 3,
            "guild_id" => @guild_id
          }
        ]))
      end)

      assert {:ok, [%{
        id: "111111111111111111",
        name: "Team Meeting",
        description: "Weekly sync",
        scheduled_start_time: "2026-03-01T14:00:00Z",
        status: 1,
        entity_type: 3,
        guild_id: @guild_id
      }]} = ListScheduledEvents.focus(%{"guild_id" => @guild_id}, %{})
    end

    test "returns empty list when no events exist" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = ListScheduledEvents.focus(%{"guild_id" => @guild_id}, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"message" => "Missing Permissions"}))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} =
        ListScheduledEvents.focus(%{"guild_id" => @guild_id}, %{})
    end
  end
end
