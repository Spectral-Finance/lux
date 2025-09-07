defmodule Lux.Lenses.Discord.Guilds.GetNotificationSettingsTest do
  @moduledoc """
  Test suite for the GetNotificationSettings module.
  These tests verify the lens's ability to:
  - Fetch notification settings from a Discord guild
  - Handle Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.GetNotificationSettings

  @guild_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches notification settings" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => @guild_id,
          "name" => "Test Server",
          "default_message_notifications" => 0,
          "explicit_content_filter" => 1,
          "system_channel_flags" => 0
        }))
      end)

      assert {:ok, %{
        default_message_notifications: 0,
        explicit_content_filter: 1,
        system_channel_flags: 0
      }} = GetNotificationSettings.focus(%{
        "guild_id" => @guild_id
      }, %{})
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = GetNotificationSettings.focus(%{
        "guild_id" => @guild_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates schema" do
      lens = GetNotificationSettings.view()
      assert lens.schema.required == ["guild_id"]
      assert Map.has_key?(lens.schema.properties, :guild_id)
    end
  end
end
