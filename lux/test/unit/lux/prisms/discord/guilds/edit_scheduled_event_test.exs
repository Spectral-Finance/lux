defmodule Lux.Prisms.Discord.Guilds.EditScheduledEventTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Guilds.EditScheduledEvent

  @guild_id "123456789012345678"
  @event_id "987654321098765432"
  @channel_id "456789012345678901"
  @event_name "Updated Game Night"
  @start_time "2024-04-01T19:00:00Z"
  @end_time "2024-04-01T21:00:00Z"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully updates a voice channel event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "name" => @event_name,
          "description" => "Updated: Join us for some fun games!",
          "scheduled_start_time" => @start_time,
          "scheduled_end_time" => @end_time,
          "entity_type" => 2,  # VOICE
          "channel_id" => @channel_id,
          "privacy_level" => 2  # GUILD_ONLY
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => @event_name
        }))
      end)

      assert {:ok, response} = EditScheduledEvent.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        name: @event_name,
        description: "Updated: Join us for some fun games!",
        scheduled_start_time: @start_time,
        scheduled_end_time: @end_time,
        entity_type: "voice",
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)

      assert response.updated == true
      assert response.event_id == @event_id
      assert response.name == @event_name
    end

    test "successfully updates an external event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["entity_type"] == 3  # EXTERNAL
        assert decoded["entity_metadata"] == %{"location" => "Updated Location: Central Park"}
        refute Map.has_key?(decoded, "channel_id")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => "Community Meetup"
        }))
      end)

      assert {:ok, response} = EditScheduledEvent.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        name: "Community Meetup",
        scheduled_start_time: @start_time,
        entity_type: "external",
        entity_metadata: %{
          location: "Updated Location: Central Park"
        },
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)

      assert response.updated == true
    end

    test "successfully updates event with image" do
      image = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert get_in(Jason.decode!(body), ["image"]) == image

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => @event_name
        }))
      end)

      assert {:ok, _response} = EditScheduledEvent.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice",
        channel_id: @channel_id,
        image: image,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)
    end

    test "returns error for invalid guild_id" do
      assert {:error, "Missing or invalid guild_id"} = EditScheduledEvent.handler(%{
        guild_id: "",
        event_id: @event_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice"
      }, @agent_ctx)
    end

    test "returns error for invalid event_id" do
      assert {:error, "Missing or invalid event_id"} = EditScheduledEvent.handler(%{
        guild_id: @guild_id,
        event_id: "",
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice"
      }, @agent_ctx)
    end

    test "returns error for invalid entity_type" do
      assert {:error, "Invalid entity_type"} = EditScheduledEvent.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "invalid"
      }, @agent_ctx)
    end

    test "returns error for missing channel_id in voice event" do
      assert {:error, "Channel ID is required for stage/voice events"} = EditScheduledEvent.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice"
      }, @agent_ctx)
    end

    test "returns error for missing location in external event" do
      assert {:error, "Location is required for external events"} = EditScheduledEvent.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "external"
      }, @agent_ctx)
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "code" => 50_013,
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"code" => 50_013, "message" => "Missing Permissions"}} = EditScheduledEvent.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice",
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)
    end
  end
end
