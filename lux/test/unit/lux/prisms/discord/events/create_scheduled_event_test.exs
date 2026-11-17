defmodule Lux.Prisms.Discord.Events.CreateScheduledEventTest do
  @moduledoc """
  Test suite for the CreateScheduledEvent module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Events.CreateScheduledEvent

  @guild_id "123456789012345678"
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
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["name"] == "Community Meetup"
        assert decoded["privacy_level"] == 2
        assert decoded["entity_type"] == 3

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111111111111111111",
          "name" => "Community Meetup",
          "guild_id" => @guild_id
        }))
      end)

      assert {:ok, %{
        created: true,
        event_id: "111111111111111111",
        name: "Community Meetup",
        guild_id: @guild_id
      }} = CreateScheduledEvent.handler(
        %{
          guild_id: @guild_id,
          name: "Community Meetup",
          scheduled_start_time: "2024-12-25T18:00:00Z",
          privacy_level: 2,
          entity_type: 3,
          entity_metadata: %{location: "Discord Stage"}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "message" => "Invalid Form Body"
        }))
      end)

      assert {:error, {400, "Invalid Form Body"}} = CreateScheduledEvent.handler(
        %{
          guild_id: @guild_id,
          name: "Event",
          scheduled_start_time: "2024-12-25T18:00:00Z",
          privacy_level: 2,
          entity_type: 3
        },
        @agent_ctx
      )
    end

    test "validates missing name" do
      assert {:error, "Missing or invalid name"} =
        CreateScheduledEvent.handler(
          %{
            guild_id: @guild_id,
            scheduled_start_time: "2024-12-25T18:00:00Z",
            privacy_level: 2,
            entity_type: 3
          },
          @agent_ctx
        )
    end
  end
end
