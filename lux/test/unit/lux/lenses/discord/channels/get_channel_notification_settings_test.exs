defmodule Lux.Lenses.Discord.Channels.GetChannelNotificationSettingsTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Channels.GetChannelNotificationSettings

  @channel_id "123456789"

  describe "focus/2" do
    test "successfully gets channel notification settings" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", @channel_id) == "/api/v10/channels/#{@channel_id}/notification-settings"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "muted" => false,
          "message_notifications" => 1,
          "mute_config" => %{
            "end_time" => nil,
            "selected_time_window" => nil
          },
          "channel_overrides" => %{
            "muted" => false,
            "message_notifications" => 0
          }
        }))
      end)

      assert {:ok, settings} = GetChannelNotificationSettings.focus(%{
        channel_id: @channel_id
      })

      assert settings.muted == false
      assert settings.message_notifications == 1
      assert settings.mute_config.end_time == nil
      assert settings.mute_config.selected_time_window == nil
      assert settings.channel_overrides.muted == false
      assert settings.channel_overrides.message_notifications == 0
    end

    test "handles channel not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.replace(conn.request_path, ":channel_id", "invalid_id") == "/api/v10/channels/invalid_id/notification-settings"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "message" => "Unknown Channel"
        }))
      end)

      assert {:error, %{"message" => "Unknown Channel"}} = GetChannelNotificationSettings.focus(%{
        channel_id: "invalid_id"
      })
    end
  end
end
