defmodule Lux.Prisms.Discord.Guilds.SendEventReminderTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Guilds.SendEventReminder

  @guild_id "123456789012345678"
  @event_id "987654321098765432"
  @channel_id "456789012345678901"
  @event_name "Community Game Night"
  @start_time "2024-04-01T19:00:00Z"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully sends a reminder for voice event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => @event_name,
          "scheduled_start_time" => @start_time,
          "entity_type" => 2,  # VOICE
          "channel_id" => @channel_id
        }))
      end)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        embed = decoded["embeds"] |> List.first()
        assert embed["title"] == "🔔 Event Reminder: #{@event_name}"
        assert embed["fields"] |> Enum.any?(fn field ->
          field["name"] == "Start Time" && field["value"] == @start_time
        end)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "message_id"}))
      end)

      assert {:ok, response} = SendEventReminder.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)

      assert response.sent == true
      assert response.event_id == @event_id
      assert response.channel_id == @channel_id
    end

    test "successfully sends a reminder for external event" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => "Community Meetup",
          "scheduled_start_time" => @start_time,
          "entity_type" => 3,  # EXTERNAL
          "entity_metadata" => %{
            "location" => "Central Park"
          }
        }))
      end)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        embed = decoded["embeds"] |> List.first()
        assert embed["fields"] |> Enum.any?(fn field ->
          field["name"] == "Location" && field["value"] == "Central Park"
        end)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"id" => "message_id"}))
      end)

      assert {:ok, response} = SendEventReminder.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)

      assert response.sent == true
      assert response.event_id == @event_id
      assert response.channel_id == @channel_id
    end

    test "returns error for invalid guild_id" do
      assert {:error, "Missing or invalid guild_id"} = SendEventReminder.handler(%{
        guild_id: "",
        event_id: @event_id,
        channel_id: @channel_id
      }, @agent_ctx)
    end

    test "returns error for invalid event_id" do
      assert {:error, "Missing or invalid event_id"} = SendEventReminder.handler(%{
        guild_id: @guild_id,
        event_id: "",
        channel_id: @channel_id
      }, @agent_ctx)
    end

    test "returns error for invalid channel_id" do
      assert {:error, "Missing or invalid channel_id"} = SendEventReminder.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        channel_id: ""
      }, @agent_ctx)
    end

    test "handles Discord API error for event fetch" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "code" => 50_001,
          "message" => "Event not found"
        }))
      end)

      assert {:error, {404, "Event not found"}} = SendEventReminder.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)
    end

    test "handles Discord API error for message send" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/scheduled-events/#{@event_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @event_id,
          "name" => @event_name,
          "scheduled_start_time" => @start_time,
          "entity_type" => 2
        }))
      end)

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/#{@channel_id}/messages"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "code" => 50_013,
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = SendEventReminder.handler(%{
        guild_id: @guild_id,
        event_id: @event_id,
        channel_id: @channel_id,
        plug: {Req.Test, DiscordClientMock}
      }, @agent_ctx)
    end
  end
end
