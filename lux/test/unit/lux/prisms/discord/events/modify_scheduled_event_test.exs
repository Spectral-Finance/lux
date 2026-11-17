defmodule Lux.Prisms.Discord.Events.ModifyScheduledEventTest do
  @moduledoc """
  Test suite for the ModifyScheduledEvent module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Events.ModifyScheduledEvent

  @guild_id "123456789012345678"
  @event_id "111111111111111111"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully modifies a scheduled event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "Updated Event"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => "Updated Event"
        }))
      end)

      assert {:ok, %{
        modified: true,
        event_id: @event_id,
        guild_id: @guild_id
      }} = ModifyScheduledEvent.handler(
        %{guild_id: @guild_id, event_id: @event_id, name: "Updated Event"},
        @agent_ctx
      )
    end

    test "modifies event status" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["status"] == 4

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => "Event",
          "status" => 4
        }))
      end)

      assert {:ok, %{modified: true}} = ModifyScheduledEvent.handler(
        %{guild_id: @guild_id, event_id: @event_id, status: 4},
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Guild Scheduled Event"
        }))
      end)

      assert {:error, {404, "Unknown Guild Scheduled Event"}} =
        ModifyScheduledEvent.handler(
          %{guild_id: @guild_id, event_id: @event_id, name: "Updated"},
          @agent_ctx
        )
    end
  end
end
