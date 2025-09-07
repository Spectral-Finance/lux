defmodule Lux.Prisms.Discord.Channels.SetChannelNotificationSettingsTest do
  @moduledoc """
  Test suite for the SetChannelNotificationSettings module.
  These tests verify the prism's ability to:
  - Update channel notification settings
  - Handle different notification levels and options
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Channels.SetChannelNotificationSettings

  @channel_id "123456789012345678"
  @guild_id "987654321098765432"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully updates all notification settings" do
      mute_until = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_iso8601()

      settings = %{
        "notification_level" => 1,
        "message_notifications" => 2,
        "suppress_everyone" => true,
        "suppress_roles" => true,
        "mobile_push" => false,
        "mute_until" => mute_until
      }

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/users/@me/guilds/#{@guild_id}/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map == settings

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(Map.merge(settings, %{
          "id" => @channel_id,
          "guild_id" => @guild_id
        })))
      end)

      assert {:ok, %{
        updated: true,
        channel_id: @channel_id,
        guild_id: @guild_id,
        settings: %{
          notification_level: 1,
          message_notifications: 2,
          suppress_everyone: true,
          suppress_roles: true,
          mobile_push: false,
          mute_until: ^mute_until
        }
      }} = SetChannelNotificationSettings.handler(
        %{
          channel_id: @channel_id,
          guild_id: @guild_id,
          notification_level: 1,
          message_notifications: 2,
          suppress_everyone: true,
          suppress_roles: true,
          mobile_push: false,
          mute_until: mute_until,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully updates partial settings" do
      settings = %{
        "notification_level" => 2,
        "suppress_everyone" => true
      }

      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/users/@me/guilds/#{@guild_id}/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map == settings

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(Map.merge(settings, %{
          "id" => @channel_id,
          "guild_id" => @guild_id,
          "message_notifications" => 0,
          "suppress_roles" => false,
          "mobile_push" => true,
          "mute_until" => nil
        })))
      end)

      assert {:ok, %{
        updated: true,
        channel_id: @channel_id,
        guild_id: @guild_id,
        settings: %{
          notification_level: 2,
          message_notifications: 0,
          suppress_everyone: true,
          suppress_roles: false,
          mobile_push: true,
          mute_until: nil
        }
      }} = SetChannelNotificationSettings.handler(
        %{
          channel_id: @channel_id,
          guild_id: @guild_id,
          notification_level: 2,
          suppress_everyone: true,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/users/@me/guilds/#{@guild_id}/channels/#{@channel_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, {403, "Missing Permissions"}} = SetChannelNotificationSettings.handler(
        %{
          channel_id: @channel_id,
          guild_id: @guild_id,
          notification_level: 1,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SetChannelNotificationSettings.view()
      assert prism.input_schema.required == ["channel_id", "guild_id"]
      assert Map.has_key?(prism.input_schema.properties, :channel_id)
      assert Map.has_key?(prism.input_schema.properties, :guild_id)
      assert Map.has_key?(prism.input_schema.properties, :notification_level)
      assert Map.has_key?(prism.input_schema.properties, :message_notifications)
      assert Map.has_key?(prism.input_schema.properties, :suppress_everyone)
      assert Map.has_key?(prism.input_schema.properties, :suppress_roles)
      assert Map.has_key?(prism.input_schema.properties, :mobile_push)
      assert Map.has_key?(prism.input_schema.properties, :mute_until)
    end

    test "validates output schema" do
      prism = SetChannelNotificationSettings.view()
      assert prism.output_schema.required == ["updated"]
      assert Map.has_key?(prism.output_schema.properties, :updated)
      assert Map.has_key?(prism.output_schema.properties, :channel_id)
      assert Map.has_key?(prism.output_schema.properties, :guild_id)
      assert Map.has_key?(prism.output_schema.properties, :settings)
    end
  end
end
