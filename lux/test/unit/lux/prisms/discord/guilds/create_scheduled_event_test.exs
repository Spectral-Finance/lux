defmodule Lux.Prisms.Discord.Guilds.CreateScheduledEventTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Guilds.CreateScheduledEvent

  @guild_id "123456789012345678"
  @channel_id "987654321098765432"
  @event_name "Community Game Night"
  @start_time "2024-04-01T18:00:00Z"
  @end_time "2024-04-01T20:00:00Z"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a voice channel event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{
          "name" => @event_name,
          "description" => "Join us for some fun games!",
          "scheduled_start_time" => @start_time,
          "scheduled_end_time" => @end_time,
          "entity_type" => 2,  # VOICE
          "channel_id" => @channel_id,
          "privacy_level" => 2  # GUILD_ONLY
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111222333444555666",
          "name" => @event_name
        }))
      end)

      assert {:ok, response} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        name: @event_name,
        description: "Join us for some fun games!",
        scheduled_start_time: @start_time,
        scheduled_end_time: @end_time,
        entity_type: "voice",
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)

      assert response.created == true
      assert response.event_id == "111222333444555666"
      assert response.name == @event_name
    end

    test "successfully creates a stage event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert get_in(Jason.decode!(body), ["entity_type"]) == 1  # STAGE_INSTANCE
        assert get_in(Jason.decode!(body), ["channel_id"]) == @channel_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111222333444555666",
          "name" => "Community Talk Show"
        }))
      end)

      assert {:ok, response} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        name: "Community Talk Show",
        scheduled_start_time: @start_time,
        entity_type: "stage_instance",
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)

      assert response.created == true
    end

    test "successfully creates an external event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["entity_type"] == 3  # EXTERNAL
        assert decoded["entity_metadata"] == %{"location" => "Central Park"}
        refute Map.has_key?(decoded, "channel_id")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111222333444555666",
          "name" => "Community Meetup"
        }))
      end)

      assert {:ok, response} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        name: "Community Meetup",
        scheduled_start_time: @start_time,
        entity_type: "external",
        entity_metadata: %{
          location: "Central Park"
        },
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)

      assert response.created == true
    end

    test "successfully creates event with image" do
      image = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert get_in(Jason.decode!(body), ["image"]) == image

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "111222333444555666",
          "name" => @event_name
        }))
      end)

      assert {:ok, _response} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice",
        channel_id: @channel_id,
        image: image,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)
    end

    test "returns error for invalid guild_id" do
      assert {:error, "Missing or invalid guild_id"} = CreateScheduledEvent.handler(%{
        guild_id: "",
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice"
      }, @agent_ctx)
    end

    test "returns error for missing name" do
      assert {:error, "Missing or invalid name"} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        scheduled_start_time: @start_time,
        entity_type: "voice"
      }, @agent_ctx)
    end

    test "returns error for invalid entity_type" do
      assert {:error, "Invalid entity_type"} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "invalid"
      }, @agent_ctx)
    end

    test "returns error for missing channel_id in voice event" do
      assert {:error, "Channel ID is required for stage/voice events"} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice"
      }, @agent_ctx)
    end

    test "returns error for missing location in external event" do
      assert {:error, "Location is required for external events"} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "external"
      }, @agent_ctx)
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "code" => 50_013,
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"code" => 50_013, "message" => "Missing Permissions"}} = CreateScheduledEvent.handler(%{
        guild_id: @guild_id,
        name: @event_name,
        scheduled_start_time: @start_time,
        entity_type: "voice",
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)
    end
  end
end
